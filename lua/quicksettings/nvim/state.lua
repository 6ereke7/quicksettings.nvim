local builtins = require("quicksettings.nvim.builtins")
local persistence = require("quicksettings.nvim.persistence")
local validation = require("quicksettings.nvim.validation")

local M = {}

function M.new(registry)
  local state = {}
  local values
  local defaults
  local saved_values = {}

  local function notify_error(message)
    vim.notify("Quick Settings: " .. message, vim.log.levels.ERROR)
  end

  local function save()
    return persistence.save(values, saved_values, notify_error)
  end

  local function apply_plugin_setting(entry, value)
    local ok, result = pcall(entry.apply, value)
    if not ok then
      notify_error(string.format("could not apply '%s': %s", entry.id, tostring(result)))
      return false
    end
    if result == false then
      notify_error(string.format("could not apply '%s': callback returned false", entry.id))
      return false
    end
    return true
  end

  local function restore_plugin_setting(entry, value)
    if not apply_plugin_setting(entry, value) then
      notify_error(string.format("rollback failed for plugin setting '%s'", entry.id))
    end
  end

  local function apply_builtin_option(key)
    local ok, err = pcall(builtins.apply_option, key, values)
    if not ok then
      notify_error(string.format("could not apply built-in setting '%s': %s", key, tostring(err)))
      return false
    end
    return true
  end

  local function restore_builtin_values(previous)
    values = vim.deepcopy(previous)
    for key in pairs(values) do
      apply_builtin_option(key)
    end
    for _, entry in ipairs(registry.entries()) do
      if entry.kind == "setting" and values[entry.id] ~= nil then
        restore_plugin_setting(entry, values[entry.id])
      end
    end
  end

  local function set_plugin_value(entry, value)
    local valid, message = validation.validate_value(entry, value)
    if not valid then
      notify_error(string.format("invalid value for '%s': %s", entry.id, message))
      return false
    end

    local previous = values[entry.id]
    values[entry.id] = value
    if not apply_plugin_setting(entry, value) then
      values[entry.id] = previous
      restore_plugin_setting(entry, previous)
      return false
    end
    if not save() then
      values[entry.id] = previous
      restore_plugin_setting(entry, previous)
      return false
    end
    return true
  end

  function state.register_plugin_setting(entry)
    if not values then
      notify_error("call load() before registering plugin entries")
      return false
    end

    local previous_value = values[entry.id]
    local previous_saved_value = saved_values[entry.id]
    local previous_entry = registry.get(entry.id)
    local initial = values[entry.id]
    if initial == nil then
      initial = saved_values[entry.id]
    end
    if initial == nil then
      initial = entry.default
    else
      local valid, validation_error = validation.validate_value(entry, initial)
      if not valid then
        notify_error(string.format("ignoring invalid saved value for '%s': %s", entry.id, validation_error))
        initial = entry.default
      end
    end

    values[entry.id] = initial
    saved_values[entry.id] = nil
    local function rollback_registration()
      values[entry.id] = previous_value
      saved_values[entry.id] = previous_saved_value
      if previous_entry and previous_value ~= nil then
        restore_plugin_setting(previous_entry, previous_value)
      else
        restore_plugin_setting(entry, entry.default)
      end
    end

    if not apply_plugin_setting(entry, values[entry.id]) then
      rollback_registration()
      return false
    end
    if not save() then
      rollback_registration()
      return false
    end
    return true
  end

  function state.is_loaded()
    return values ~= nil
  end

  function state.load()
    defaults = builtins.defaults()
    values = vim.deepcopy(defaults)
    local has_saved_settings
    saved_values, has_saved_settings = persistence.load(notify_error)

    for key, default in pairs(values) do
      local value = saved_values[key]
      if value ~= nil then
        if type(default) == "boolean" and type(value) == "boolean" then
          values[key] = value
        elseif key == "flavour" and vim.tbl_contains(builtins.flavours, value) then
          values[key] = value
        else
          notify_error("ignoring invalid saved value for " .. key)
        end
      end
    end

    for key in pairs(values) do
      if key ~= "flavour" and key ~= "statusline" and key ~= "bufferline" then
        builtins.apply_option(key, values)
      end
    end

    local group = vim.api.nvim_create_augroup("QuickSettings", { clear = true })
    vim.api.nvim_create_autocmd("WinEnter", {
      group = group,
      callback = function()
        if values then
          builtins.apply_window_options(values)
        end
      end,
    })

    if not has_saved_settings then
      save()
    end
  end

  function state.get(key)
    return values and values[key]
  end

  function state.set_builtin(key, value)
    if not values or values[key] == nil then
      return false
    end

    local previous = values[key]
    values[key] = value
    if not apply_builtin_option(key) then
      values[key] = previous
      apply_builtin_option(key)
      return false
    end
    if not save() then
      values[key] = previous
      apply_builtin_option(key)
      return false
    end
    return true
  end

  function state.cycle_flavour()
    if not values then
      return
    end

    local current = vim.fn.index(builtins.flavours, values.flavour)
    local next_flavour = builtins.flavours[((current + 1) % #builtins.flavours) + 1]
    state.set_builtin("flavour", next_flavour)
  end

  function state.set_plugin_value(id, value)
    local entry = registry.get(id)
    if not entry or entry.kind ~= "setting" then
      return false
    end
    return set_plugin_value(entry, value)
  end

  function state.reset_setting(id)
    local entry = registry.get(id)
    if entry and entry.kind == "setting" then
      return set_plugin_value(entry, entry.default)
    end

    if defaults and defaults[id] ~= nil then
      local previous = values[id]
      values[id] = vim.deepcopy(defaults[id])
      if not apply_builtin_option(id) then
        values[id] = previous
        apply_builtin_option(id)
        return false
      end
      if not save() then
        values[id] = previous
        apply_builtin_option(id)
        return false
      end
      return true
    end

    return false
  end

  function state.reset_all()
    if not values or not defaults then
      notify_error("call load() before resetting settings")
      return false
    end

    local previous = vim.deepcopy(values)
    for key, value in pairs(defaults) do
      values[key] = vim.deepcopy(value)
    end

    for _, entry in ipairs(registry.entries()) do
      if entry.kind == "setting" then
        values[entry.id] = vim.deepcopy(entry.default)
      end
    end

    for key in pairs(defaults) do
      if not apply_builtin_option(key) then
        restore_builtin_values(previous)
        return false
      end
    end

    for _, entry in ipairs(registry.entries()) do
      if entry.kind == "setting" and not apply_plugin_setting(entry, values[entry.id]) then
        restore_builtin_values(previous)
        return false
      end
    end

    if not save() then
      restore_builtin_values(previous)
      return false
    end

    return true
  end

  function state.apply_visibility()
    if values then
      builtins.apply_visibility(values)
    end
  end

  return state
end

return M

local validation = require("plugins.quicksettings.validation")

local M = {}
local entries = {}
local setting_handler
local load_check

local function notify_error(message)
  vim.notify("Quick Settings: " .. message, vim.log.levels.ERROR)
end

local function register(spec, kind)
  if not load_check or not load_check() then
    notify_error("call load() before registering plugin entries")
    return false
  end

  local entry = validation.normalize_entry(spec, kind, notify_error)
  if not entry then
    return false
  end

  local previous = entries[entry.id]
  if previous and previous.kind ~= kind then
    notify_error(string.format("plugin entry '%s' is already registered as a %s", entry.id, previous.kind))
    return false
  end

  if kind == "setting" then
    if not setting_handler then
      notify_error("call load() before registering plugin entries")
      return false
    end
    if not setting_handler(entry) then
      return false
    end
  end

  entries[entry.id] = entry
  return true
end

function M.set_setting_handler(handler)
  setting_handler = handler
end

function M.set_load_check(handler)
  load_check = handler
end

function M.register_setting(spec)
  return register(spec, "setting")
end

function M.register_action(spec)
  return register(spec, "action")
end

function M.get(id)
  return entries[id]
end

function M.entries()
  local result = {}
  for _, entry in pairs(entries) do
    result[#result + 1] = entry
  end
  table.sort(result, function(left, right)
    if left.section == right.section then
      return left.id < right.id
    end
    return left.section < right.section
  end)
  return result
end

return M

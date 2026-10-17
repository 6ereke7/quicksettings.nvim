local M = {}

function M.validate_value(entry, value)
  if entry.choices then
    if not vim.tbl_contains(entry.choices, value) then
      return false, "value is not one of the configured choices"
    end
  elseif entry.type == "number" then
    if type(value) ~= "number" or (entry.integer and value % 1 ~= 0) then
      return false, entry.integer and "value must be an integer" or "value must be a number"
    end
    if value ~= value or value == math.huge or value == -math.huge then
      return false, "value must be finite"
    end
    if entry.min ~= nil and value < entry.min then
      return false, "value is below the minimum of " .. entry.min
    end
    if entry.max ~= nil and value > entry.max then
      return false, "value is above the maximum of " .. entry.max
    end
  elseif entry.type == "string" then
    if type(value) ~= "string" then
      return false, "value must be text"
    end
    local length = vim.fn.strchars(value)
    if entry.min_length ~= nil and length < entry.min_length then
      return false, "value is shorter than " .. entry.min_length .. " characters"
    end
    if entry.max_length ~= nil and length > entry.max_length then
      return false, "value is longer than " .. entry.max_length .. " characters"
    end
  elseif type(value) ~= "boolean" then
    return false, "value must be boolean"
  end

  if entry.validate then
    local ok, valid, message = pcall(entry.validate, value)
    if not ok then
      return false, "validation failed: " .. tostring(valid)
    end
    if valid ~= true then
      return false, message or "value did not pass validation"
    end
  end

  return true
end

function M.normalize_entry(spec, kind, notify_error)
  local function reject(message)
    notify_error(message)
    return nil
  end

  local valid_id = type(spec) == "table"
    and type(spec.id) == "string"
    and spec.id:match("^[%w_-]+%.[%w_.-]+$") ~= nil
  if not valid_id then
    return reject("plugin entry ids must be namespaced, e.g. 'gitsigns.current_line_blame'")
  end
  if type(spec.section) ~= "string" or spec.section == ""
    or type(spec.label) ~= "string" or spec.label == ""
  then
    return reject(string.format("plugin entry '%s' needs a section and label", spec.id))
  end
  if kind == "setting" and type(spec.apply) ~= "function" then
    return reject(string.format("plugin setting '%s' needs an apply function", spec.id))
  end
  if kind == "action" and type(spec.action) ~= "function" then
    return reject(string.format("plugin action '%s' needs an action function", spec.id))
  end

  local entry = vim.tbl_extend("force", {}, spec)
  entry.kind = kind
  if kind == "action" then
    return entry
  end

  local inferred_type = entry.choices and "choice" or type(entry.default)
  entry.type = entry.type or inferred_type
  if entry.type ~= "boolean" and entry.type ~= "choice"
    and entry.type ~= "number" and entry.type ~= "string"
  then
    return reject(string.format("plugin setting '%s' has an unsupported type", entry.id))
  end
  if entry.type == "choice" and type(entry.choices) ~= "table" then
    return reject(string.format("plugin setting '%s' needs a choices list", entry.id))
  end
  if entry.type ~= "choice" and entry.choices ~= nil then
    return reject(string.format("plugin setting '%s' cannot combine type and choices", entry.id))
  end
  if entry.type == "boolean" and type(entry.default) ~= "boolean"
    or entry.type == "number" and type(entry.default) ~= "number"
    or entry.type == "string" and type(entry.default) ~= "string"
  then
    return reject(string.format("plugin setting '%s' default does not match its type", entry.id))
  end
  if entry.type == "number" then
    if entry.min ~= nil and type(entry.min) ~= "number"
      or entry.max ~= nil and type(entry.max) ~= "number"
    then
      return reject(string.format("plugin setting '%s' min/max must be numbers", entry.id))
    end
    if entry.min and entry.max and entry.min > entry.max then
      return reject(string.format("plugin setting '%s' min must not exceed max", entry.id))
    end
    if entry.integer ~= nil and type(entry.integer) ~= "boolean" then
      return reject(string.format("plugin setting '%s' integer must be a boolean", entry.id))
    end
  elseif entry.type == "string" then
    for _, field in ipairs({ "min_length", "max_length" }) do
      local value = entry[field]
      if value ~= nil and (type(value) ~= "number" or value < 0 or value % 1 ~= 0) then
        return reject(string.format(
          "plugin setting '%s' %s must be a non-negative integer",
          entry.id,
          field
        ))
      end
    end
    if entry.min_length and entry.max_length and entry.min_length > entry.max_length then
      return reject(string.format("plugin setting '%s' min_length must not exceed max_length", entry.id))
    end
  end
  for _, field in ipairs({ "prompt", "hint" }) do
    if entry[field] ~= nil and type(entry[field]) ~= "string" then
      return reject(string.format("plugin setting '%s' %s must be a string", entry.id, field))
    end
  end
  if entry.validate ~= nil and type(entry.validate) ~= "function" then
    return reject(string.format("plugin setting '%s' validate must be a function", entry.id))
  end
  if entry.type == "choice" then
    if #entry.choices == 0 or not vim.tbl_contains(entry.choices, entry.default) then
      return reject(string.format("plugin setting '%s' default must be one of its choices", entry.id))
    end
    for _, choice in ipairs(entry.choices) do
      local choice_type = type(choice)
      if choice_type ~= "string" and choice_type ~= "number" and choice_type ~= "boolean" then
        return reject(string.format(
          "plugin setting '%s' choices must be strings, numbers, or booleans",
          entry.id
        ))
      end
    end
  end

  local valid_default, default_error = M.validate_value(entry, entry.default)
  if not valid_default then
    return reject(string.format(
      "plugin setting '%s' default does not satisfy its constraints: %s",
      entry.id,
      default_error
    ))
  end

  return entry
end

return M

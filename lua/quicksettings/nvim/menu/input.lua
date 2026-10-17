local M = {}

local function format_value(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  return tostring(value)
end

local function format_prompt(entry, current)
  local details = {
    "current: " .. format_value(current),
    "default: " .. format_value(entry.default),
  }

  if entry.type == "number" then
    if entry.min ~= nil then
      details[#details + 1] = "min: " .. tostring(entry.min)
    end
    if entry.max ~= nil then
      details[#details + 1] = "max: " .. tostring(entry.max)
    end
    if entry.integer then
      details[#details + 1] = "integer"
    end
  else
    if entry.min_length ~= nil then
      details[#details + 1] = "min length: " .. tostring(entry.min_length)
    end
    if entry.max_length ~= nil then
      details[#details + 1] = "max length: " .. tostring(entry.max_length)
    end
  end

  if entry.hint then
    details[#details + 1] = entry.hint
  end

  return (entry.prompt or (entry.label .. ": ")) .. " [" .. table.concat(details, "; ") .. "] "
end

function M.edit(entry, current, settings, on_change)
  vim.ui.input({
    prompt = format_prompt(entry, current),
    default = type(current) == "string" and current or tostring(current),
  }, function(input)
    if input == nil then
      return
    end

    local value = input
    if entry.type == "number" then
      value = tonumber(input)
      if value == nil then
        vim.notify(
          string.format("Quick Settings: '%s' must be a number", entry.label),
          vim.log.levels.ERROR
        )
        return
      end
    end

    if settings._set_plugin_value(entry.id, value) and on_change then
      on_change(entry.id)
    end
  end)
end

return M

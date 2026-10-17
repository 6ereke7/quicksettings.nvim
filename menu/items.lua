local input = require("plugins.quicksettings.menu.input")

local M = {}

local function format_value(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  return tostring(value)
end

local function builtin_item(Menu, settings, id, label)
  return Menu.item(string.format("%s: %s", label, settings.get(id) and "ON" or "OFF"), {
    id = id,
    action = function()
      settings._set_builtin(id, not settings.get(id))
    end,
  })
end

local function action_item(Menu, id, label, action, close_after)
  return Menu.item(label, {
    id = id,
    action = action,
    close_after = close_after,
  })
end

local function plugin_item(Menu, settings, entry, on_change)
  if entry.kind == "action" then
    return Menu.item(entry.label, {
      id = entry.id,
      close_after = entry.close_after,
      action = entry.action,
    })
  end

  local current = settings.get(entry.id)
  local display_value = type(current) == "boolean" and (current and "ON" or "OFF") or format_value(current)
  return Menu.item(entry.label .. ": " .. display_value, {
    id = entry.id,
    action = function()
      if entry.type == "boolean" then
        settings._set_plugin_value(entry.id, not current)
      elseif entry.type == "choice" then
        local index = vim.fn.index(entry.choices, current)
        local next_value = entry.choices[((index + 1) % #entry.choices) + 1]
        settings._set_plugin_value(entry.id, next_value)
      else
        input.edit(entry, current, settings, on_change)
      end
    end,
  })
end

function M.build(Menu, settings, on_change)
  local items = {
    builtin_item(Menu, settings, "number", "Numbers"),
    builtin_item(Menu, settings, "relativenumber", "Relative Numbers"),
    builtin_item(Menu, settings, "wrap", "Word Wrap"),
    builtin_item(Menu, settings, "cursorline", "Cursorline"),
    builtin_item(Menu, settings, "hlsearch", "Highlight Search"),
    builtin_item(Menu, settings, "spell", "Spell Check"),
    builtin_item(Menu, settings, "list", "Show Whitespace"),
    builtin_item(Menu, settings, "ignorecase", "Ignore Case"),
    builtin_item(Menu, settings, "smartcase", "Smart Case"),
    builtin_item(Menu, settings, "signcolumn", "Sign Column"),
    Menu.separator("Appearance"),
    action_item(
      Menu,
      "flavour",
      "Catppuccin Flavour: " .. settings.get("flavour"):gsub("^%l", string.upper),
      settings._cycle_flavour
    ),
    builtin_item(Menu, settings, "statusline", "Statusline"),
    builtin_item(Menu, settings, "bufferline", "Buffer Tabs"),
    Menu.separator("Plugins (Lazy)"),
    action_item(Menu, "lazy-ui", "Open Lazy UI", function()
      vim.cmd("Lazy")
    end, true),
    action_item(Menu, "lazy-check", "Lazy check", function()
      vim.cmd("Lazy check")
    end, true),
    action_item(Menu, "lazy-sync", "Lazy sync", function()
      vim.cmd("Lazy sync")
    end, true),
    action_item(Menu, "lazy-log", "Lazy log", function()
      vim.cmd("Lazy log")
    end, true),
  }

  local current_section
  for _, entry in ipairs(settings._entries()) do
    if entry.section ~= current_section then
      current_section = entry.section
      items[#items + 1] = Menu.separator(current_section)
    end
    items[#items + 1] = plugin_item(Menu, settings, entry, on_change)
  end

  return items
end

return M

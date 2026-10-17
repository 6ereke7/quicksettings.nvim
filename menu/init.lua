local Items = require("plugins.quicksettings.menu.items")

local M = {}

function M.open(settings)
  local Menu = require("nui.menu")
  local menu
  local refresh_items
  local function build_items()
    return Items.build(Menu, settings, function(selected_id)
      if refresh_items then
        refresh_items(selected_id)
      end
    end)
  end

  local lines = build_items()
  local title = " Quick Settings: <CR> edit/toggle, r reset, R reset all "
  local width = vim.api.nvim_strwidth(title)
  for _, entry in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(entry.text))
  end
  width = math.min(width + 8, math.max(1, vim.o.columns - 6))
  local height = math.min(#lines, math.max(1, vim.o.lines - 6))

  menu = Menu({
    relative = "editor",
    position = {
      row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
      col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    },
    anchor = "NW",
    size = { width = width, height = height },
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = { top = title, top_align = "center" },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual",
    },
  }, {
    lines = lines,
    min_width = width,
    max_width = width,
    max_height = height,
    keymap = {
      focus_next = { "j", "<Down>" },
      focus_prev = { "k", "<Up>" },
      close = { "<Esc>", "<C-k>" },
      submit = { "<CR>" },
    },
  })
  menu:mount()

  refresh_items = function(selected_id)
    if not vim.api.nvim_win_is_valid(menu.winid) then
      return
    end

    local current_line = vim.api.nvim_win_get_cursor(menu.winid)[1]
    local updated_lines = build_items()
    menu.tree:set_nodes(updated_lines)
    menu.tree:render()

    for line, entry in ipairs(updated_lines) do
      if entry.id == selected_id then
        vim.api.nvim_win_set_cursor(menu.winid, { line, 0 })
        return
      end
    end
    vim.api.nvim_win_set_cursor(menu.winid, { math.min(current_line, #updated_lines), 0 })
  end

  menu:map("n", "<CR>", function()
    local selected = menu.tree:get_node()
    if not selected or not selected.action then
      return
    end
    if selected.close_after then
      menu:unmount()
      selected.action()
      return
    end

    local selected_id = selected.id
    selected.action()
    refresh_items(selected_id)
  end, { noremap = true, nowait = true }, true)

  menu:map("n", "r", function()
    local selected = menu.tree:get_node()
    if not selected or not settings.reset_setting(selected.id) then
      vim.notify("Quick Settings: selected item has no resettable setting", vim.log.levels.INFO)
      return
    end
    refresh_items(selected.id)
  end, { noremap = true, nowait = true }, true)

  menu:map("n", "R", function()
    if settings.reset_all() then
      local selected = menu.tree:get_node()
      refresh_items(selected and selected.id)
    end
  end, { noremap = true, nowait = true }, true)
end

return M

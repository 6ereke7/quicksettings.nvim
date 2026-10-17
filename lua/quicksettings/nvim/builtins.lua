local M = {}

M.flavours = { "latte", "frappe", "macchiato", "mocha" }

function M.defaults()
  return {
    number = vim.wo.number,
    relativenumber = vim.wo.relativenumber,
    wrap = vim.wo.wrap,
    cursorline = vim.wo.cursorline,
    hlsearch = vim.go.hlsearch,
    spell = vim.wo.spell,
    list = vim.wo.list,
    ignorecase = vim.go.ignorecase,
    smartcase = vim.go.smartcase,
    signcolumn = vim.wo.signcolumn ~= "no",
    flavour = "mocha",
    statusline = true,
    bufferline = true,
  }
end

function M.apply_visibility(values)
  vim.o.laststatus = values.statusline and 3 or 0
  vim.o.showtabline = values.bufferline and 2 or 0
end

function M.apply_option(key, values)
  if key == "number" then
    vim.wo.number = values.number
  elseif key == "relativenumber" then
    vim.wo.relativenumber = values.relativenumber
  elseif key == "wrap" then
    vim.wo.wrap = values.wrap
  elseif key == "cursorline" then
    vim.wo.cursorline = values.cursorline
  elseif key == "hlsearch" then
    vim.go.hlsearch = values.hlsearch
  elseif key == "spell" then
    vim.wo.spell = values.spell
  elseif key == "list" then
    vim.wo.list = values.list
  elseif key == "ignorecase" then
    vim.go.ignorecase = values.ignorecase
  elseif key == "smartcase" then
    vim.go.smartcase = values.smartcase
  elseif key == "signcolumn" then
    vim.wo.signcolumn = values.signcolumn and "yes" or "no"
  elseif key == "flavour" then
    vim.cmd.colorscheme("catppuccin-" .. values.flavour)
  elseif key == "statusline" or key == "bufferline" then
    M.apply_visibility(values)
  end
end

function M.apply_window_options(values)
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end

  for _, key in ipairs({
    "number",
    "relativenumber",
    "wrap",
    "cursorline",
    "spell",
    "list",
    "signcolumn",
  }) do
    M.apply_option(key, values)
  end
end

return M

# Quick Settings for Neovim

Quick Settings provides a small, keyboard-driven settings menu for Neovim.
It gives users a convenient place to toggle editor options and lets plugin
authors expose their own settings and actions through a simple Lua API.

The menu is built with [NUI](https://github.com/MunifTanjim/nui.nvim); prompts
use Neovim's built-in `vim.ui.input`. Settings are saved automatically as JSON
and restored on the next startup.

## Features

- Centered NUI menu with viewport-aware sizing and scrolling.
- Built-in editor options for line numbers, wrapping, search, spell checking,
  whitespace, sign column, statusline, and buffer tabs.
- Boolean, choice, numeric, and text settings registered by plugins or user
  configuration.
- Custom validation, numeric and text constraints, and prompt hints.
- Actions that can keep the menu open or close it before opening another UI.
- Per-setting and reset-all shortcuts.
- Automatic JSON persistence, including values for plugins that are currently
  unloaded.
- Atomic settings-file replacement and rollback when applying or saving a
  change fails.

## Requirements

- Neovim 0.10 or newer.
- [NUI](https://github.com/MunifTanjim/nui.nvim), the only required plugin
  dependency.

Quick Settings does not import or require Gitsigns, a Git executable, Catppuccin,
or lazy.nvim as Lua modules. The default menu includes integrations for
Catppuccin theme flavours and lazy.nvim's `:Lazy` commands; those specific
controls are useful when the corresponding theme or command is already
installed, but are not needed for the settings menu or the registration API.

### About the Git entry

Quick Settings itself does not add a Git section or depend on Gitsigns. In the
configuration where this module was developed, a separate `git.lua` plugin
configuration registers a `gitsigns.current_line_blame` setting through the
public API. Any plugin can register entries in the same way. If Gitsigns is not
installed or that registration is omitted, Quick Settings has no Git setting
to display.

## Installation

This source layout is intended to live at
`lua/plugins/quicksettings/` in a Neovim configuration. Clone the repository
there, replacing `YOUR_GITHUB_USERNAME` with the GitHub repository owner:

```sh
git clone https://github.com/YOUR_GITHUB_USERNAME/quicksettings.nvim.git \
  ~/.config/nvim/lua/plugins/quicksettings
```

Install NUI with your plugin manager. For lazy.nvim, add a plugin spec such as:

```lua
-- lua/plugins/nui.lua
return {
  "MunifTanjim/nui.nvim",
}
```

Load Quick Settings during startup, before plugin configurations register
settings:

```lua
local quicksettings = require("plugins.quicksettings")
quicksettings.load()
```

The menu can be opened from a keymap such as:

```lua
vim.keymap.set("n", "<C-k>", function()
  require("plugins.quicksettings").open()
end, { desc = "Quick settings" })
```

If your configuration uses a custom lazy.nvim spec loader, keep the local
`quicksettings/` source directory out of plugin-spec discovery; it is a Lua
module directory, not a lazy.nvim spec. The NUI plugin spec should still be
loaded normally.

## Usage

Open the menu with your configured keymap. Built-in settings and registered
plugin entries are grouped in the menu.

| Key | Action |
| --- | --- |
| `<CR>` | Toggle, cycle, edit, or run the selected entry |
| `j` / `<Down>` | Move to the next entry |
| `k` / `<Up>` | Move to the previous entry |
| `r` | Reset the selected setting to its default |
| `R` | Reset built-in and registered plugin settings |
| `<Esc>` / `<C-k>` | Close the menu |

Changes are saved in `quicksettings.json` in Neovim's configuration directory.
Values for registered plugin settings are restored when that plugin registers
again. Unknown saved values are preserved, so temporarily unloaded plugins do
not lose their settings.

## Plugin API

Require the public module as `plugins.quicksettings`. Call `load()` once during
startup before registering plugin entries.

### Boolean setting

Boolean settings toggle with `<CR>`. `apply(value)` is called when the setting
registers and whenever its value changes.

```lua
local quicksettings = require("plugins.quicksettings")

quicksettings.register_setting({
  id = "gitsigns.current_line_blame",
  section = "Git",
  label = "Current Line Blame",
  default = true,
  apply = function(value)
    require("gitsigns").toggle_current_line_blame(value)
  end,
})
```

Use a dotted, namespaced ID (`plugin_name.setting_name`). Register plugin
settings after the plugin is configured and available, for example in its
`config` callback. A plugin-specific `apply` function may then safely use that
plugin's API.

### Choice setting

Provide `choices` to cycle through supported values. The default must be one of
the choices.

```lua
quicksettings.register_setting({
  id = "example.layout",
  section = "Example",
  label = "Layout",
  default = "compact",
  choices = { "compact", "wide" },
  apply = function(value)
    -- Apply the selected layout.
  end,
})
```

### Numeric and text settings

Use `type = "number"` or `type = "string"` to edit a value with Neovim's input
prompt. The current value is prefilled, and the prompt shows the current and
default values. Text values are quoted in the menu and prompt.

Numeric settings support `min`, `max`, and `integer`. Text settings support
`min_length` and `max_length`. Both types accept an optional `validate` function
that returns `true` for valid input or `false, "reason"` to reject it. Use
`hint` to describe any additional validation requirements.

```lua
quicksettings.register_setting({
  id = "editor.scrolloff",
  section = "Editor",
  label = "Scroll Offset",
  type = "number",
  default = 8,
  min = 0,
  max = 30,
  integer = true,
  apply = function(value)
    vim.o.scrolloff = value
  end,
})

quicksettings.register_setting({
  id = "example.project_label",
  section = "Example",
  label = "Project Label",
  type = "string",
  default = "",
  prompt = "Project label: ",
  max_length = 40,
  hint = "up to 40 characters",
  validate = function(value)
    return value ~= "", "label cannot be empty"
  end,
  apply = function(value)
    vim.g.project_label = value
  end,
})
```

Invalid values and cancelled prompts are not saved or applied.

### Actions

Use `register_action` to add a command or other plugin action. Set
`close_after = true` if it opens another window or interface.

```lua
quicksettings.register_action({
  id = "telescope.find_files",
  section = "Telescope",
  label = "Find Files",
  close_after = true,
  action = function()
    require("telescope.builtin").find_files()
  end,
})
```

### Apply failures and persistence

An `apply(value)` callback can reject an update by returning `false` or raising
an error. Quick Settings restores the previous value and attempts to apply it
again. If saving fails, the runtime value is also rolled back. A failed rollback
is reported with a Neovim notification.

## Development and tests

Run the headless UI, validation, persistence, and rollback tests from the
repository root:

```sh
sh tests/run-quicksettings.sh
```

The test runner opens the real NUI menu, inspects its rendered buffers and
window bounds, feeds menu keypresses, stubs `vim.ui.input`, and starts a second
Neovim process to verify JSON restoration. NUI must already be installed. Set
`NUI_PATH` if it is not in the default Lazy path:

```sh
NUI_PATH=/path/to/nui.nvim sh tests/run-quicksettings.sh
```

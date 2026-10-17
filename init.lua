local registry = require("plugins.quicksettings.registry")
local state = require("plugins.quicksettings.state").new(registry)

registry.set_setting_handler(state.register_plugin_setting)
registry.set_load_check(state.is_loaded)

local M = {
  register_setting = registry.register_setting,
  register_action = registry.register_action,
  _entries = registry.entries,
  get = state.get,
  load = state.load,
  reset_setting = state.reset_setting,
  reset_all = state.reset_all,
  apply_visibility = state.apply_visibility,
  _set_builtin = state.set_builtin,
  _cycle_flavour = state.cycle_flavour,
  _set_plugin_value = state.set_plugin_value,
}

function M.open()
  require("plugins.quicksettings.menu").open(M)
end

return M

local M = {}

local function settings_path()
  return vim.fn.stdpath("config") .. "/quicksettings.json"
end

local function remove_temporary_file(path, notify_error)
  if vim.fn.filereadable(path) ~= 1 and vim.fn.isdirectory(path) ~= 1 then
    return
  end

  local ok, result = pcall(vim.fn.delete, path)
  if not ok or result ~= 0 then
    notify_error("could not remove temporary settings file " .. path .. ": "
      .. tostring(ok and result or result))
  end
end

function M.load(notify_error)
  local path = settings_path()
  if vim.fn.filereadable(path) ~= 1 then
    return {}, false
  end

  local read_ok, lines = pcall(vim.fn.readfile, path)
  local ok, saved
  if read_ok then
    ok, saved = pcall(vim.json.decode, table.concat(lines, "\n"))
  else
    ok, saved = false, lines
  end

  if not ok or type(saved) ~= "table" then
    notify_error("could not read saved settings from " .. path .. ": " .. tostring(saved))
    return {}, true
  end

  return vim.deepcopy(saved), true
end

function M.save(values, saved_values, notify_error)
  local directory = vim.fn.stdpath("config")
  local mkdir_ok, mkdir_error = pcall(vim.fn.mkdir, directory, "p")
  if not mkdir_ok or vim.fn.isdirectory(directory) ~= 1 then
    notify_error("could not create settings directory: " .. directory)
    if not mkdir_ok then
      notify_error(tostring(mkdir_error))
    end
    return false
  end

  local persisted = vim.deepcopy(saved_values)
  for key, value in pairs(values) do
    persisted[key] = value
  end

  local ok, encoded = pcall(vim.json.encode, persisted)
  if not ok then
    notify_error("could not encode settings: " .. tostring(encoded))
    return false
  end

  local path = settings_path()
  local temporary_path = path .. ".tmp." .. tostring(vim.fn.getpid())
  local write_ok, result = pcall(vim.fn.writefile, { encoded }, temporary_path)
  if not write_ok or result ~= 0 then
    remove_temporary_file(temporary_path, notify_error)
    notify_error("could not write temporary settings file " .. temporary_path
      .. ": " .. tostring(write_ok and result or result))
    return false
  end

  local rename_ok, renamed, rename_error = pcall(vim.uv.fs_rename, temporary_path, path)
  if not rename_ok or not renamed then
    remove_temporary_file(temporary_path, notify_error)
    notify_error("could not replace settings file " .. path .. ": "
      .. tostring(rename_ok and rename_error or renamed))
    return false
  end

  return true
end

return M

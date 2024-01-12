local json_or_nil = require("sg.utils").json_or_nil

local M = {}

--- File location where information is stored
M.data_file = require("sg.utils").joinpath(vim.fn.stdpath "data", "cody.json")

--- Get cody data
---@return CodyConfig
M.get_cody_data = function()
  ---@type CodyConfig
  local cody_data = {
    tos_accepted = false,
  }

  local decoded = json_or_nil(M.data_file)
  if decoded then
    cody_data = decoded
  end

  if not cody_data.ignored_notifications then
    cody_data.ignored_notifications = {}
  end

  return cody_data or {}
end

--- Write cody config to file
---@param cody_data CodyConfig
M.write_cody_data = function(cody_data)
  -- Clear old data that we don't need anymore
  cody_data.endpoint = nil
  cody_data.token = nil

  vim.fn.writefile({ vim.json.encode(cody_data) }, M.data_file)
end

-- Read the version from the Cargo.toml file
M.version = (function()
  local plugin_file = require("plenary.debug_utils").sourced_filepath()
  local root = require("sg.utils").joinpath(
    vim.fn.fnamemodify(plugin_file, ":p:h:h:h:h"),
    "Cargo.toml"
  )
  for _, line in ipairs(vim.fn.readfile(root)) do
    if line:find "version" then
      local version = vim.split(line, " = ")[2] or ""
      return vim.trim(version:gsub('"', ""))
    end
  end
end)() or "<unexpected error>"

return M

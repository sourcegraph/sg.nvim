local M = {}

--- File location where information is stored
M.data_file = require("sg.utils").joinpath(vim.fn.stdpath "data", "cody.json")

--- Get cody data
---@return CodyConfig
M.get_cody_data = function()
  local handle = io.open(M.data_file, "r")

  ---@type CodyConfig
  local cody_data = {
    tos_accepted = false,
  }

  if handle ~= nil then
    local contents = handle:read "*a"
    handle:close()

    local ok, decoded = pcall(vim.json.decode, contents)
    if ok and decoded then
      cody_data = decoded
    end
  end

  return cody_data or {}
end

--- Write cody config to file
---@param cody_data CodyConfig
local write_cody_data = function(cody_data)
  vim.fn.writefile({ vim.json.encode(cody_data) }, M.data_file)
end

return M

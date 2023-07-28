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

  return cody_data or {}
end

--- Write cody config to file
---@param cody_data CodyConfig
M.write_cody_data = function(cody_data)
  vim.fn.writefile({ vim.json.encode(cody_data) }, M.data_file)
end

return M

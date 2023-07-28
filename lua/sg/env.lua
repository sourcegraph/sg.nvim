local data_file = require("sg.utils").joinpath(vim.fn.stdpath "data", "cody.json")

--- Get cody data
---@return CodyConfig
local get_cody_data = function()
  local handle = io.open(data_file, "r")

  ---@type CodyConfig
  local cody_data = {
    tos_accepted = false,
  }

  if handle ~= nil then
    local contents = handle:read "*a"
    local ok, decoded = pcall(vim.json.decode, contents)
    if ok and decoded then
      cody_data = decoded
    end
  end

  return cody_data
end

--- Write cody config to file
---@param cody_data CodyConfig
local write_cody_data = function(cody_data)
  vim.fn.writefile({ vim.json.encode(cody_data) }, data_file)
end

local M = {}

M.set_token = function(token)
  token = token or vim.fn.inputsecret "SRC_ACCESS_TOKEN > "
  local cody_data = get_cody_data()
  cody_data.token = token
  write_cody_data(cody_data)

  return cody_data
end

M.token = function(interactive)
  local token = vim.env.SRC_ACCESS_TOKEN
  if token and token ~= "" then
    return token
  end

  local cody_data = get_cody_data()
  if cody_data.token then
    return cody_data.token
  end

  if interactive then
    cody_data = M.set_token()
  end

  return cody_data.token or ""
end

M.set_endpoint = function(endpoint)
  endpoint = endpoint or vim.fn.input "SRC_ENDPOINT > "
  local cody_data = get_cody_data()
  cody_data.endpoint = endpoint
  write_cody_data(cody_data)

  return cody_data
end

M.endpoint = function(interactive)
  local endpoint = vim.env.SRC_ENDPOINT
  if endpoint and endpoint ~= "" then
    return endpoint
  end

  local cody_data = get_cody_data()
  if cody_data.endpoint then
    return cody_data.endpoint
  end

  if interactive then
    cody_data = M.set_endpoint()
  end

  return cody_data.endpoint or ""
end

return M

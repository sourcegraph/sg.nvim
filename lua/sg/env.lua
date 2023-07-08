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

return {
  token = function(interactive)
    local token = vim.env.SRC_ACCESS_TOKEN
    if token and token ~= "" then
      return token
    end

    local cody_data = get_cody_data()
    if cody_data.token then
      return cody_data.token
    end

    if interactive then
      cody_data.token = vim.fn.inputsecret "SRC_ACCESS_TOKEN > "
      write_cody_data(cody_data)
    end

    return cody_data.token or ""
  end,

  endpoint = function(interactive)
    local endpoint = vim.env.SRC_ENDPOINT
    if endpoint and endpoint ~= "" then
      return endpoint
    end

    local cody_data = get_cody_data()
    if cody_data.endpoint then
      return cody_data.endpoint
    end

    if interactive then
      cody_data.endpoint = vim.fn.input "SRC_ENDPOINT > "
      write_cody_data(cody_data)
    end

    return cody_data.endpoint or ""
  end,
}

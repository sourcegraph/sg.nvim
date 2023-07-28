local config = require "sg.config"
local data = require "sg.data"

local strategy = require("sg.types").auth_strategy

local M = {}

local valid = function(s)
  return s and type(s) == "string" and s ~= ""
end

local strategies = {
  [strategy.app] = function()
    local locations = {
      "~/Library/Application Support/com.sourcegraph.cody/app.json",
    }

    if vim.env.XDG_DATA_HOME then
      table.insert(locations, vim.env.XDG_DATA_HOME .. "/com.sourcegraph.cody/app.json")
    end

    table.insert(locations, vim.fn.expand "$HOME/.local/share/com.sourcegraph.cody/app.json")

    -- TODO: Handle windows paths
    -- table.insert(vim"{FOLDERID_LocalAppData}/com.sourcegraph.cody/app.json",

    for _, file in ipairs(locations) do
      local handle = io.open(file)
      if handle then
        local contents = handle:read "*a"
        handle:close()

        local ok, parsed = vim.json.decode(contents)
        if ok and parsed and valid(parsed.token) and valid(parsed.endpoint) then
          return { token = parsed.token, endpoint = parsed.endpoint }
        end
      end
    end

    return nil
  end,
  [strategy.nvim] = function()
    local cody_data = data.get_cody_data()

    if cody_data and valid(cody_data.endpoint) and valid(cody_data.token) then
      return { endpoint = cody_data.endpoint, token = cody_data.token }
    end

    return nil
  end,
  [strategy.env] = function()
    if valid(vim.env.SRC_ENDPOINT) and valid(vim.env.SRC_ACCESS_TOKEN) then
      return { endpoint = vim.env.SRC_ENDPOINT, token = vim.env.SRC_ACCESS_TOKEN }
    end

    return nil
  end,
}

M.set_token = function(token)
  token = token or vim.fn.inputsecret "SRC_ACCESS_TOKEN > "
  local cody_data = data.get_cody_data()
  cody_data.token = token
  data.write_cody_data(cody_data)

  return cody_data
end

M.token = function(interactive)
  local token = vim.env.SRC_ACCESS_TOKEN
  if token and token ~= "" then
    return token
  end

  local cody_data = data.get_cody_data()
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
  local cody_data = data.get_cody_data()
  cody_data.endpoint = endpoint
  data.write_cody_data(cody_data)

  return cody_data
end

M.endpoint = function(interactive)
  local endpoint = vim.env.SRC_ENDPOINT
  if endpoint and endpoint ~= "" then
    return endpoint
  end

  local cody_data = data.get_cody_data()
  if cody_data.endpoint then
    return cody_data.endpoint
  end

  if interactive then
    cody_data = M.set_endpoint()
  end

  return cody_data.endpoint or ""
end

M.valid = function()
  return true
end

return M

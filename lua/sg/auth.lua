---@tag sg.auth
---@config { ["module"] = "sg.auth" }

---@brief [[
--- How to manage authentication for Sourcegraph within Neovim
--- (both for Cody and for Sourcegraph)
---
--- To manage your sourcegraph account, visit:
---     - https://sourcegraph.com/cody/manage
---
--- Use SRC_ENDPOINT and SRC_ACCESS_TOKEN environment variables to
--- manually override previous configuration.
---
--- If you're not using the environment variables, then you may need to
--- authenticate when accessing the variables on startup. If you prefer to
--- not have this behavior, then you should load the environment variables
--- into the environment before opening neovim.
---
--- Otherwise use |:SourcegraphLogin| to set up authentication.
---
--- NOTE: Cody-App support has been removed (for now).
--- We're currently exploring what App will look like in the future,
--- but it will not currently be supported anymore.
---
---@brief ]]

local M = {}

local valid = function(s)
  return s and type(s) == "string" and s ~= ""
end

-- Initialize values from environment when possible
local endpoint = vim.env.SRC_ENDPOINT
local token = vim.env.SRC_ACCESS_TOKEN

--- Gets authorization from the environment variables.
---     It is possible these will be initialized from previous
---     session configuration, if not already present.
---
---@return SourcegraphAuthConfig?
M.get = function()
  if valid(endpoint) and valid(token) then
    return { endpoint = endpoint, token = token }
  end

  return nil
end

M.set = function(new_endpoint, new_token, opts)
  opts = opts or {}

  if not valid(new_endpoint) or not valid(new_token) then
    error "endpoint and token must be valid strings"
  end

  -- If we already have auth, then don't update from initialization
  --    I think this is the logic you would want to have happen.
  --    This makes sure existing env is the one that overrides
  if opts.initialize and endpoint and token then
    return
  end

  vim.env.SRC_ENDPOINT = new_endpoint
  vim.env.SRC_ACCESS_TOKEN = new_token

  -- Update local vars
  endpoint = vim.env.SRC_ENDPOINT
  token = vim.env.SRC_ACCESS_TOKEN

  if not opts.initialize then
    -- Notify nvim-agent that the configuration has changed
    require("sg.rpc").get_auth({ endpoint = new_endpoint, token = new_token }, function()
      -- Notify Cody that configuration has changed
      require("sg.cody.rpc").config_did_change()
    end)
  else
    require("sg.cody.rpc").config_did_change()
  end

  vim.schedule(function()
    require("sg.cody.rpc").graphql_currentUserIsPro(function(err, data)
      if err then
        return
      end

      M._is_pro = data
    end)
  end)
end

M.is_pro = function()
  if M._is_pro == nil then
    -- TODO: Probably want to check a bit more than that.
    vim.wait(100)
  end

  return M._is_pro
end

return M

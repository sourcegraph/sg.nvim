---@tag sg.auth
---@config { ["module"] = "sg.auth" }

---@brief [[
--- How to manage authentication for Sourcegraph within Neovim
--- (both for Cody and for Sourcegraph)
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

local endpoint = vim.env.SRC_ENDPOINT
local token = vim.env.SRC_ACCESS_TOKEN

-- TODO: Don't know if this is a good idea or not
-- local timer = vim.loop.new_timer()
-- timer:start(
--   0,
--   10000,
--   vim.schedule_wrap(function()
--     endpoint = vim.env.SRC_ENDPOINT
--     token = vim.env.SRC_ACCESS_TOKEN
--   end)
-- )

--- Gets authorization from the environment variables.
---     It is possible these will be initialized from previous
---     session configuration, if not already present.
---
---@return SourcegraphAuthConfig?
M.get = function()
  if valid(endpoint) and valid(endpoint) then
    return { endpoint = endpoint, token = token }
  end

  return nil
end

M.set = function(new_endpoint, new_token, opts)
  opts = opts or {}

  if not valid(new_endpoint) or not valid(new_token) then
    error "endpoint and token must be valid strings"
  end

  vim.env.SRC_ENDPOINT = new_endpoint
  vim.env.SRC_ACCESS_TOKEN = new_token

  -- Update local vars
  endpoint = vim.env.SRC_ENDPOINT
  token = vim.env.SRC_ACCESS_TOKEN

  if not opts.from_agent then
    -- Notify nvim-agent that the configuration has changed
    require("sg.rpc").get_auth({ endpoint = new_endpoint, token = new_token }, function()
      -- Notify Cody that configuration has changed
      require("sg.cody.rpc").config_did_change()
    end)
  else
    require("sg.cody.rpc").config_did_change()
  end
end

return M

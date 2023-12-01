---@tag sg.auth
---@config { ["module"] = "sg.auth" }

---@brief [[
--- How to manage authentication for Sourcegraph within Neovim
--- (both for Cody and for Sourcegraph)
---
--- Use SRC_ENDPOINT and SRC_ACCESS_TOKEN environment variables to
--- manually override previous configuration.
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

--- Gets authorization from the environment variables.
---     It is possible these will be initialized from previous
---     session configuration, if not already present.
---
---@return SourcegraphAuthConfig?
M.get = function()
  if valid(vim.env.SRC_ENDPOINT) and valid(vim.env.SRC_ACCESS_TOKEN) then
    return { endpoint = vim.env.SRC_ENDPOINT, token = vim.env.SRC_ACCESS_TOKEN }
  end

  return nil
end

M.set = function(endpoint, token)
  if not valid(endpoint) or not valid(token) then
    error "endpoint and token must be valid strings"
  end

  vim.env.SRC_ENDPOINT = endpoint
  vim.env.SRC_ACCESS_TOKEN = token
end

return M

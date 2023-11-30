---@tag sg.auth
---@config { ["module"] = "sg.auth" }

---@brief [[
--- How to manage authentication for Sourcegraph within Neovim
--- (both for Cody and for Sourcegraph)
---
--- NOTE: Cody-App support has been removed (for now).
--- We're currently exploring what App will look like in the future,
--- but it will not currently be supported anymore.
---
---@brief ]]

local data = require "sg.private.data"

local strategy = require("sg.types").auth_strategy

local M = {}

local valid = function(s)
  return s and type(s) == "string" and s ~= ""
end

--- Gets authorization in the following order:
--- - Environment variables `SRC_ENDPOINT` and `SRC_ACCESS_TOKEN`
--- - Stored login from |:SourcegraphLogin|
---
--- Returns nil if no valid configuration was found.
---
---@return SourcegraphAuthConfig?
---@return SourcegraphAuthStrategy?
M.get = function()
  -- Environment var check
  if valid(vim.env.SRC_ENDPOINT) and valid(vim.env.SRC_ACCESS_TOKEN) then
    return { endpoint = vim.env.SRC_ENDPOINT, token = vim.env.SRC_ACCESS_TOKEN }, strategy.env
  end

  -- TODO: Delete this one next.
  -- Also, backfill this change by deleting the key from cody data. That would also be good.
  local cody_data = data.get_cody_data()
  if cody_data and valid(cody_data.endpoint) and valid(cody_data.token) then
    return { endpoint = cody_data.endpoint, token = cody_data.token }, strategy.nvim
  end

  return nil, nil
end

local cached_valid_conf = nil

--- Can force reload
M.reload = function()
  cached_valid_conf = nil
  return M.valid()
end

--- Gets whether the current configuration is valid.
---@param opts { cached: boolean }?
---@return boolean
M.valid = function(opts)
  opts = opts or {}

  if not opts.cached or cached_valid_conf == nil then
    require("sg").accept_tos()

    cached_valid_conf = M.get() ~= nil
  end

  return cached_valid_conf
end

--- Set the nvim auth. Will optionally prompt user for auth if nothing is passed.
---@param opts SourcegraphAuthConfig?
M.set_nvim_auth = function(opts)
  cached_valid_conf = nil

  opts = opts or {}
  opts.endpoint = opts.endpoint
    or vim.fn.input {
      prompt = "SRC_ENDPOINT > ",
      default = "https://sourcegraph.com",
    }

  opts.token = opts.token or vim.fn.inputsecret "SRC_ACCESS_TOKEN > "

  if opts.endpoint:sub(1, 4) ~= "http" then
    opts.endpoint = "https://" .. opts.endpoint
  end

  assert(opts.token, "[sg-cody] Nvim auth must have a token")
  assert(opts.endpoint, "[sg-cody] Nvim auth must have an endpoint")

  local cody_data = data.get_cody_data()
  cody_data.token = opts.token
  cody_data.endpoint = opts.endpoint
  data.write_cody_data(cody_data)
end

return M

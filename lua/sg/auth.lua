---@tag sg.auth
---@config { ["module"] = "sg.auth" }

---@brief [[
--- How to manage authentication for Sourcegraph within Neovim
--- (both for Cody and for Sourcegraph)
---
---@brief ]]

local config = require "sg.config"
local data = require "sg.private.data"

local json_or_nil = require("sg.utils").json_or_nil
local strategy = require("sg.types").auth_strategy

local M = {}

local valid = function(s)
  return s and type(s) == "string" and s ~= ""
end

-- TODO: It does feel a bit weird to read the files all the time,
-- but I think it's alright for now -- it also makes the state
-- always correct with whatever their current file is.

--- The default strategies for sg.nvim. Use |config.auth_strategy| to configure the
--- order of evaluation. Whichever one returns a valid configuration first will be used
--- when starting and connecting to Sourcegraph and Cody.
---@eval { ["description"] = require('sg.auth').__docs() }
---@type table<SourcegraphAuthStrategy, SourcegraphAuthObject>
M.strategies = {
  [strategy.app] = {
    doc = "Use the Cody App configuration to connect to your sourcegraph instance."
      .. " See https://sourcegraph.com/get-cody for more information",
    get = function()
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
        local parsed = json_or_nil(file)
        if parsed and valid(parsed.token) and valid(parsed.endpoint) then
          return { token = parsed.token, endpoint = parsed.endpoint }
        end
      end

      return nil
    end,
  },
  [strategy.nvim] = {
    doc = "Create a custom configuration for neovim.",
    get = function()
      local cody_data = data.get_cody_data()

      if cody_data and valid(cody_data.endpoint) and valid(cody_data.token) then
        return { endpoint = cody_data.endpoint, token = cody_data.token }
      end

      return nil
    end,
  },
  [strategy.env] = {
    doc = "Use the environment variables `SRC_ENDPOINT` and `SRC_ACCESS_TOKEN` to determine which instance to connect to",
    get = function()
      if valid(vim.env.SRC_ENDPOINT) and valid(vim.env.SRC_ACCESS_TOKEN) then
        return { endpoint = vim.env.SRC_ENDPOINT, token = vim.env.SRC_ACCESS_TOKEN }
      end

      return nil
    end,
  },
}

--- Get the highest priority active auth configuration.
--- By default loads the ordering from the user config.
---
---@param ordering SourcegraphAuthStrategy[]?
---@return SourcegraphAuthConfig?
---@return SourcegraphAuthStrategy?
M.get = function(ordering)
  ordering = ordering or config.auth_strategy
  for _, order in ipairs(ordering) do
    local f = M.strategies[order]
    if f then
      local result = f.get()
      if result then
        return result, order
      end
    end
  end

  return nil, nil
end

M.get_all_valid = function(ordering)
  ordering = ordering or config.auth_strategy

  local results = {}
  for _, order in ipairs(ordering) do
    local res = M.get { order }
    if res then
      table.insert(results, { res, order })
    end
  end

  return results
end

M.valid = function()
  return M.get() ~= nil
end

--- Set the nvim auth. Will optionally prompt user for auth if nothing is passed.
---@param opts SourcegraphAuthConfig?
M.set_nvim_auth = function(opts)
  opts = opts or {}
  opts.endpoint = opts.endpoint or vim.fn.input "SRC_ENDPOINT > "
  opts.token = opts.token or vim.fn.inputsecret "SRC_ACCESS_TOKEN > "

  assert(opts.token, "[sg-cody] Nvim auth must have a token")
  assert(opts.endpoint, "[sg-cody] Nvim auth must have an endpoint")

  local cody_data = data.get_cody_data()
  cody_data.token = opts.token
  cody_data.endpoint = opts.endpoint
  data.write_cody_data(cody_data)
end

M.__docs = function()
  local result = {}
  for _, strat in ipairs(config.auth_strategy) do
    local obj = M.strategies[strat]

    table.insert(result, string.format('Auth Strategy: `"%s"`<br>', strat))
    table.insert(result, "  " .. obj.doc .. "<br>")
    table.insert(result, "<br>")
  end

  return result
end

return M

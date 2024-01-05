---@tag sg.nvim
---@config { ["name"] = "INTRODUCTION" }

---@brief [[
--- sg.nvim is a plugin for interfacing with Sourcegraph and Cody
---
--- To login, either:
---
--- - Run `:SourcegraphLogin` after following installation instructions for `sourcegraph.com` usage.
--- - Run `:SourcegraphLogin!` and provide an endpoint and access token to be stored.
--- - Use the `SRC_ENDPOINT` and `SRC_ACCESS_TOKEN` environment variables to manage tokens for enterprise usage.
---   - See [src-cli](https://github.com/sourcegraph/src-cli#log-into-your-sourcegraph-instance) for more info
---
--- See `:help sg.auth` for more information.
---
--- You can check that you're logged in by then running `:checkhealth sg`
---@brief ]]

local M = {}

-- Private var to determine if setup has been called.
-- Primarily usesful for health checks and reporting information to users
M._setup_has_been_called = false

--- Setup sourcegraph
---@param opts sg.config
M.setup = function(opts)
  opts = opts or {}

  local config = require "sg.config"
  for key, value in pairs(opts) do
    if config[key] ~= nil then
      config[key] = value
    end
  end

  require("sg.lsp").setup()
  require("sg.request").start()
  require("sg.cody.plugin.agent").setup(config)
  require("sg.cody.plugin.commands").setup(config)

  M._setup_has_been_called = true
end

return M

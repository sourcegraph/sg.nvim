---@tag sg.nvim
---@config { ["name"] = "INTRODUCTION" }

---@brief [[
--- sg.nvim is a plugin for interfacing with Sourcegraph and Cody
---
--- To configure logging in:
---
--- - Log in on your Sourcegraph instance.
--- - Click your user menu in the top right, then select Settings > Access tokens.
--- - Create your access token, and then run `:SourcegraphLogin` in your neovim editor after installation.
--- - Type in the link to your Sourcegraph instance (for example: `https://sourcegraph.com`)
--- - And then paste in your access token.
---
--- An alternative to this is to use the environment variables specified for [src-cli](https://github.com/sourcegraph/src-cli#log-into-your-sourcegraph-instance).
---
--- You can check that you're logged in by then running `:checkhealth sg`
---@brief ]]

local M = {}

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
end

return M

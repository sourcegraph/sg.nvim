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

local data = require "sg.private.data"

local M = {}

local accept_tos = function(opts)
  opts = opts or {}

  local cody_data = data.get_cody_data()
  if opts.accept_tos and not cody_data.tos_accepted then
    cody_data.tos_accepted = true
    data.write_cody_data(cody_data)
  end

  if not cody_data.tos_accepted then
    local choice = vim.fn.inputlist {
      "By using Cody, you agree to its license and privacy statement:"
        .. " https://about.sourcegraph.com/terms/cody-notice . Do you wish to proceed? Yes/No: ",
      "1. Yes",
      "2. No",
    }

    cody_data.tos_accepted = choice == 1
    data.write_cody_data(cody_data)
  end

  if not cody_data.user then
    cody_data.user = require("sg.utils").uuid()
    data.write_cody_data(cody_data)
  end

  return cody_data.tos_accepted
end

--- Setup sourcegraph
---@param opts sg.config
M.setup = function(opts)
  opts = opts or {}

  accept_tos(opts)

  local config = require "sg.config"
  for key, value in pairs(opts) do
    if config[key] ~= nil then
      config[key] = value
    end
  end

  require("sg.lsp").setup()
end

M.accept_tos = accept_tos

return M

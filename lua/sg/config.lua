---@brief [[
--- Config options for sg.nvim
---
--- All options can be set via
---
--- <code=lua>
---   require("sg").setup { ... }
--- </code>
---@brief ]]

---@config { field_heading = "Configuration Options", space_prefix = 2 }

---@tag sg.setup

---@class sg.config
---@field node_executable string: path to node executable
---@field cody_agent string: path to the cody-agent js bundle
---@field did_change_debounce number: Number of ms to debounce changes
---@field on_attach function: function to run when attaching to sourcegraph buffers

---@type sg.config
local config = {}

config.node_executable = "node"
config.cody_agent = vim.api.nvim_get_runtime_file("dist/cody-agent.js", false)[1]

config.on_attach = function(_, bufnr)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
  vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = bufnr })
end

config.testing = (vim.env.SG_NVIM_TESTING or "") == "true"

config.did_change_debounce = 500

config.get_nvim_agent = function()
  return require("sg._find_artifact").find_rust_bin "sg-nvim-agent"
end

return config

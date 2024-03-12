---@brief [[
--- Config options for sg.nvim
---
--- All options can be set via
---
--- <code=lua>
---   require("sg").setup { ... }
--- </code>
---
--- Other configuration notes:
--- - To configure options for the prompt, you can use `ftplugin/cody_prompt.lua`
--- - To configure options for the history, you can use `ftplugin/cody_history.lua`
---@brief ]]

---@config { field_heading = "Configuration Options", space_prefix = 2 }

---@tag sg.setup

---@class sg.config
---@field enable_cody boolean?: Enable/disable cody integration
---@field accept_tos boolean?: Accept the TOS without being prompted
---@field download_binaries boolean?: Default true, download latest release from Github
---@field node_executable string?: path to node executable
---@field skip_node_check boolean?: Useful if using other js runtime
---@field cody_agent string?: path to the cody-agent js bundle
---@field on_attach function?: function to run when attaching to sg://<file> buffers
---@field src_headers? table<string, string>: Headers to be sent with each sg request

---@type sg.config
local config = {
  enable_cody = true,
  accept_tos = false,
  download_binaries = true,
  node_executable = "node",
  skip_node_check = false,
  cody_agent = vim.api.nvim_get_runtime_file("dist/cody-agent.js", false)[1],

  get_nvim_agent = function()
    return require("sg.private.find_artifact").find_rust_bin "sg-nvim-agent"
  end,

  on_attach = function(_, bufnr)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
    vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = bufnr })
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
  end,

  testing = (vim.env.SG_NVIM_TESTING or "") == "true",
}

return config

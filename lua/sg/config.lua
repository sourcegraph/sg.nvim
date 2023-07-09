local config = {}

config.node_executable = "node"
config.cody_agent = vim.api.nvim_get_runtime_file("dist/cody-agent.js", false)[1]

config.on_attach = function(_, bufnr)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
  vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = bufnr })
end

config.testing = (vim.env.SG_NVIM_TESTING or "") == "true"

return config

vim.env.SG_NVIM_TESTING = "true"
vim.env.SRC_ENDPOINT = "https://sourcegraph.sourcegraph.com"

vim.opt.rtp:append { ".", "../plenary.nvim", "../tree-sitter-lua" }

vim.cmd [[runtime! plugin/plenary.vim]]
vim.cmd [[runtime! plugin/sg.lua]]
vim.cmd [[runtime! after/plugin/sg.lua]]
vim.cmd [[runtime! after/plugin/cody.lua]]
vim.cmd [[runtime! after/plugin/cody-agent.lua]]

require("sg").setup {
  download_binaries = false,
  accept_tos = true,
  enable_cody = true,
}

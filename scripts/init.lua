vim.env.SG_NVIM_TESTING = "true"

vim.env.SRC_ENDPOINT = "https://sourcegraph.com"
vim.env.SRC_ACCESS_TOKEN = "testing-token-doesnt-work"

vim.opt.rtp:append { ".", "../plenary.nvim", "../tree-sitter-lua" }

vim.cmd [[runtime! plugin/plenary.vim]]
vim.cmd [[runtime! plugin/sg.lua]]
vim.cmd [[runtime! plugin/cody.lua]]
vim.cmd [[runtime! plugin/cody-agent.lua]]

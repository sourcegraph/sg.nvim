vim.opt.rtp:append { ".", "../plenary.nvim", "../tree-sitter-lua" }

vim.cmd [[runtime! plugin/plenary.vim]]
vim.cmd [[runtime! plugin/sg.lua]]
vim.cmd [[runtime! plugin/cody.lua]]

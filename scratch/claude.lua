local bufnr = 136

local completions = R("sg.lib").get_completions [[

You are Linus Torvalds replying in the linux kernel mailing list. The response
is in the format of the mailing list. Make it very angry.

Linus saracastically writes a review of zig. He hates it. He much prefers rust.

]]

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(vim.trim(completions), "\n"))

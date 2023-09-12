if not require "sg.request" then
  return
end

local bufread = require "sg.bufread"

-- TODO: I don't know how to turn off this https://* stuff and not make netrw users mad
pcall(vim.api.nvim_clear_autocmds, {
  group = "Network",
  event = "BufReadCmd",
  pattern = "https://*",
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("sourcegraph-bufread", { clear = true }),
  pattern = { "sg://*", "https://sourcegraph.com/*" },
  callback = function(event)
    bufread.edit(event.buf or vim.api.nvim_get_current_buf(), vim.fn.expand "<amatch>" --[[@as string]])
  end,
  desc = "Sourcegraph link and protocol handler",
})

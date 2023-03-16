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
  callback = function()
    bufread.edit(vim.fn.expand "<amatch>")
  end,
})

vim.api.nvim_create_user_command("SourcegraphInfo", function()
  print "Attempting to get sourcegraph info..."

  -- TODO: Would be nice to get the version of the plugin
  local info = require("sg.lib").get_info()
  local contents = vim.split(vim.inspect(info), "\n")

  table.insert(contents, 1, "Sourcegraph info:")

  vim.cmd.vnew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, contents)

  vim.schedule(function()
    print "... got sourcegraph info"
  end)
end, {})

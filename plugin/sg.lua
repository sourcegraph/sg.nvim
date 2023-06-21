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

vim.api.nvim_create_user_command("SourcegraphLink", function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local ok, link = pcall(require("sg.lib").get_link, vim.api.nvim_buf_get_name(0), cursor[1], cursor[2] + 1)
  if not ok then
    print("Failed to get link:", link)
    return
  end

  print("Setting '+' register to:", link)
  vim.fn.setreg("+", link)
end, {})

vim.api.nvim_create_user_command("SourcegraphSearch", function(args)
  local input = nil
  if args.args and #args.args > 0 then
    input = args.args
  end

  require("sg.telescope").fuzzy_search_results { input = input }
end, {})

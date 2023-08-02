---@tag sg.commands

---@brief [[
--- Default commands for interacting with Sourcegraph
---@brief ]]

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
  desc = "Sourcegraph link and protocol handler",
})

vim.api.nvim_create_user_command("SourcegraphInfo", function()
  print "Attempting to get sourcegraph info..."

  -- TODO: Would be nice to get the version of the plugin
  local info = require("sg.lib").get_info()
  local contents = vim.split(vim.inspect(info), "\n")

  table.insert(contents, 1, "Sourcegraph info:")

  vim.cmd.vnew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, contents)
  vim.api.nvim_buf_set_option(0, "buflisted", false)
  vim.api.nvim_buf_set_option(0, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(0, "modifiable", false)
  vim.api.nvim_buf_set_option(0, "modified", false)

  vim.schedule(function()
    print "... got sourcegraph info"
  end)
end, {})

---@command SourcegraphLink [[
--- Get a sourcegraph link to the current repo + file + line.
--- Automatically adds it to your '+' register
---@command ]]
vim.api.nvim_create_user_command("SourcegraphLink", function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local ok, link = pcall(require("sg.lib").get_link, vim.api.nvim_buf_get_name(0), cursor[1], cursor[2] + 1)
  if not ok then
    print("Failed to get link:", link)
    return
  end

  print("Setting '+' register to:", link)
  vim.fn.setreg("+", link)
end, {
  desc = "Get a sourcegraph link to the current location",
})

---@command SourcegraphSearch [[
--- Run a search. For more sourcegraph search syntax, refer to online documentation
---@command ]]
vim.api.nvim_create_user_command("SourcegraphSearch", function(args)
  local input = nil
  if args.args and #args.args > 0 then
    input = args.args
  end

  require("sg.extensions.telescope").fuzzy_search_results { input = input }
end, {
  desc = "Run a search on your connected Sourcegraph instance",
})

---@command SourcegraphLogin [[
--- Get prompted for endpoint and access_token if you don't
--- want to set them via environment variables.
---@command ]]
vim.api.nvim_create_user_command("SourcegraphLogin", function()
  local auth = require "sg.auth"

  auth.set_nvim_auth()

  vim.notify "[sg-cody] Changes will come into effect after a restart"
end, {
  desc = "Login and store credentials for later use (an alternative to the environment variables",
})

---@command SourcegraphBuild [[
--- Rebuild the Sourcegraph crates and required dependencies (in case build failed during installation)
---@command ]]
vim.api.nvim_create_user_command("SourcegraphBuild", function()
  local plugin_file = require("plenary.debug_utils").sourced_filepath()
  local root = vim.fn.fnamemodify(plugin_file, ":h:h")
  local build = require("sg.utils").joinpath(root, "build", "init.lua")
  print "Starting sourcegraph build:"

  require("sg.utils").system({ "nvim", "-l", build }, { cwd = root, text = true }, function(obj)
    print(obj.stdout)
    print(obj.stderr)
    if obj.code ~= 0 then
      error "Sourcegraph Build Failed. Check `:messages`"
    else
      print "Sourcegraph Build Success! Build log in `:messages`"
    end
  end)
end, {
  desc = "Rebuild the Sourcegraph crates and required dependencies (in case build failed during installation)",
})

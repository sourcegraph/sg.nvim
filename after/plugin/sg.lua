---@tag sg.commands

---@brief [[
--- Default commands for interacting with Sourcegraph
---@brief ]]

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

---@command SourcegraphDownloadBinaries [[
--- (Re-)Download the sourcegraph binaries. This should happen during installation
--- but you can force redownloading the binaries this way to ensure that sg.nvim
--- is properly installed.
---@command ]]
vim.api.nvim_create_user_command("SourcegraphDownloadBinaries", function()
  require("sg.build").download()
end, {
  desc = "(Re-)download the sourcegraph binaries",
})

---@command SourcegraphLink [[
--- Get a sourcegraph link to the current repo + file + line.
--- Automatically adds it to your '+' register
---@command ]]
vim.api.nvim_create_user_command("SourcegraphLink", function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  print "requesting link..."

  require("sg.rpc").get_link(vim.api.nvim_buf_get_name(0), cursor[1], cursor[2] + 1, function(err, link)
    if err or not link then
      print("[sourcegraph] Failed to get link:", link)
      return
    end

    print("[sourcegraph] Setting '+' register to:", link)
    vim.fn.setreg("+", link)
  end)
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

vim.api.nvim_create_user_command("SourcegraphInfo", function()
  print "[sourcegraph-info] Use `:checkhealth sg` instead"
end, {})

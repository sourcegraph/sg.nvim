---@tag sg.commands

---@brief [[
--- Default commands for interacting with Sourcegraph
---@brief ]]

local bufread = require "sg.bufread"

-- TODO: I don't know how to turn off this https://* stuff and not make netrw users mad
--  As far as I can tell, this is the minimal amount of clearing I can do (and I'm not sure
--  who is really opening https://* links in nvim anyway)
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

vim.api.nvim_create_user_command("SourcegraphInfo", function()
  print "[sourcegraph-info] Use `:checkhealth sg` instead"
end, {})

---@command SourcegraphLogin [[
--- Get prompted for endpoint and access_token if you don't
--- want to set them via environment variables.
---
--- For enterprise instances, the only currently supported method
--- is environment variables.
---
--- If you want to force a particular endpoint + access token combination to be saved,
--- use :SourcegraphLogin! and then follow the prompts.
---@command ]]
vim.api.nvim_create_user_command("SourcegraphLogin", function(command)
  local endpoint = vim.fn.input {
    prompt = "Sourcegraph Endpoint: ",
    default = "https://sourcegraph.com/",
  }

  if command.bang then
    local token = vim.fn.inputsecret "Sourcegraph Access Token (empty to clear): "
    if type(token) == "string" then
      return require("sg.rpc").get_auth({
        endpoint = endpoint,
        token = token,
        clear = token == "",
      }, function(err)
        if err then
          vim.notify(string.format("[cody] Failed to update auth: %s", vim.inspect(err)))
        else
          vim.notify "[cody] Updated Sourcegraph Auth Information. Please restart nvim."
        end
      end)
    end
  end

  if endpoint == "https://sourcegraph.com/" then
    local port = 52068
    local editor = "NEOVIM"
    local redirect = string.format("user/settings/tokens/new/callback?requestFrom=%s-%s", editor, port)

    require("sg.rpc").dotcom_login(port, function(err, _)
      if err then
        vim.notify(string.format("Error occurred: %s", vim.inspect(err)))
        return
      end

      require("sg.utils").open(string.format("%s%s", endpoint, redirect))
    end)
  else
    print(string.format("Found endpoint: '%s', which was not `https://sourcegraph.com`", endpoint))
    print "Sorry, currently for enterprise instances, you'll need to use the environment variable methods"
    print "Set `SRC_ENDPOINT` and `SRC_ACCESS_TOKEN` in your environment before starting neovim"
  end
end, {
  desc = "Login and store credentials for later use (an alternative to using environment variables). Use <bang> to store a password",
  bang = true,
})

---@command SourcegraphClear [[
--- Remove Sourcegraph Login information
---@command ]]
vim.api.nvim_create_user_command("SourcegraphClear", function()
  return require("sg.rpc").get_auth({
    clear = true,
  }, function(err)
    if err then
      vim.notify(string.format("[cody] Failed to update auth: %s", vim.inspect(err)))
    else
      vim.notify "[cody] Cleared Sourcegraph Auth Information"
    end
  end)
end, {
  desc = "Clears stored sourcegraph credentials",
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
vim.api.nvim_create_user_command("SourcegraphLink", function(args)
  print "requesting link..."

  local region = vim.region(0, "'<", "'>", "v", true)
  local keys = vim.tbl_keys(region)
  table.sort(keys)

  local row1 = args.line1 - 1
  local row2 = args.line2 - 1

  local first = keys[1]
  local last = keys[#keys]

  local range
  if first == row1 and last == row2 then
    -- We have a visual selection
    range = {
      start_line = first + 1,
      start_col = region[first][1],
      end_line = last + 1,
      end_col = region[last][2],
    }
  else
    -- Just some range passed, or no range at all
    range = {
      start_line = args.line1,
      start_col = 0,
      end_line = args.line2,
      end_col = 0,
    }
  end

  require("sg.rpc").get_link(vim.api.nvim_buf_get_name(0), range, function(err, link)
    if err or not link then
      print("[sourcegraph] Failed to get link:", link)
      return
    end

    print("[sourcegraph] Setting '+' register to:", link)
    vim.fn.setreg("+", link)
  end)
end, {
  desc = "Get a sourcegraph link to the current location",
  range = 2,
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
  nargs = '*',
})

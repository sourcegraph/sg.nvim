-- For some reason this doesn't always get loaded?...
vim.cmd [[runtime! plugin/cody-agent.lua]]
vim.cmd [[runtime! plugin/cody.lua]]
-- local augroup_cody = vim.api.nvim_create_augroup("augroup-cody", { clear = false })

require("plenary.async").tests.add_to_env()

local async_util = require "plenary.async.util"

local cody_commands = require "sg.cody.commands"
local rpc = assert(require "sg.cody.rpc", "able to load cody rpc")

local find_initialized = function()
  return vim.tbl_filter(function(msg)
    return msg.type == "notify" and msg.method == "initialized"
  end, rpc.messages)[1]
end

describe("cody e2e", function()
  a.it("should ask through chat what file we are in", function()
    if string.sub(vim.env.SRC_ACCESS_TOKEN, 1, 4) ~= "sgp_" then
      print("\n⚠️  You need a real token to run this tests\n")
      error("Need a real token to run e2e test suite")
    end

    vim.wait(5000, find_initialized)
    async_util.scheduler()
    vim.cmd.edit [[lua/sg/auth.lua]]
    async_util.scheduler()
    bufnr = vim.api.nvim_get_current_buf()

    vim.cmd [[CodyChat]]
    cody_commands.focus_prompt()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"What file am I looking at"})

    vim.cmd.CodySubmit()
    cody_commands.focus_history()
    history_bufnr = vim.api.nvim_get_current_buf()

    vim.wait(20000, function()
      local lines = vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false)
      return #lines > 5
    end)

    local lines = vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false)
    local joinedLines = table.concat(lines, "\n")
    -- This is not necessary, but it helps to understand why it possibly failed.
    print(joinedLines)
    assert(string.find(joinedLines, "sg.nvim/lua/sg/auth.lua"), "Cody told us the path to the current file")
  end)
end)

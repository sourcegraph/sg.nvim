-- Force loading plugin files
vim.cmd [[runtime! after/plugin/cody.lua]]
vim.cmd [[runtime! after/plugin/cody-agent.lua]]

require("plenary.async").tests.add_to_env()

local cody_commands = require "sg.cody.commands"
local rpc = assert(require "sg.cody.rpc", "able to load cody rpc")

-- Create a temp directory for the stable testing data used by these tests..
local tmp_dir = vim.loop.fs_mkdtemp(string.format("%s/cody-nvim-e2e-XXXXXXX", vim.loop.os_tmpdir()))
os.execute(string.format("git clone https://github.com/sourcegraph/e2e-sg.nvim %s", tmp_dir))

local initialized = false
local find_initialized = function()
  return initialized
    and vim.tbl_filter(function(msg)
      return msg.type == "notify" and msg.method == "initialized"
    end, rpc.messages)[1]
end

describe("cody e2e", function()
  before_each(function()
    if string.sub(vim.env.SRC_ACCESS_TOKEN, 1, 4) ~= "sgp_" then
      error "Need a real token to run e2e test suite"
    end

    vim.cmd.cd(tmp_dir)

    require("sg.cody.rpc").start({}, function()
      initialized = true
    end)
  end)

  a.it("should ask through chat what file we are in", function()
    vim.wait(5000, find_initialized)

    vim.cmd.edit "pool/pool.go"

    vim.cmd.CodyChat()
    cody_commands.focus_prompt()
    local prompt_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { "What file am I looking at" })
    vim.cmd.CodySubmit()

    cody_commands.focus_history()
    local history_bufnr = vim.api.nvim_get_current_buf()

    vim.wait(20000, function()
      return vim.api.nvim_buf_line_count(history_bufnr) > 5
    end)

    local lines = table.concat(vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false), "\n")
    assert(
      string.find(lines, "/pool/pool.go"),
      string.format("Cody told us the path to the current file:\n\n %s", lines)
    )
  end)
end)

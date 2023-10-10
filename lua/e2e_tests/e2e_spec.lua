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

  local execute_test_case = function(opts)
    vim.wait(5000, find_initialized)

    vim.cmd.edit(opts.file)
    vim.wait(100)

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "// Inserting example comment" })
    vim.wait(100)

    if opts.bang then
      vim.cmd [[CodyChat!]]
    else
      vim.cmd [[CodyChat]]
    end

    cody_commands.focus_prompt()
    local prompt_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { "What file am I looking at" })
    vim.cmd.CodySubmit()

    cody_commands.focus_history()
    local history_bufnr = vim.api.nvim_get_current_buf()

    vim.wait(20000, function()
      local lines = table.concat(vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false), "\n")
      return vim.api.nvim_buf_line_count(history_bufnr) > 5 and (not not string.find(lines, opts.file))
    end)

    local lines = table.concat(vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false), "\n")
    assert(
      string.find(lines, opts.file),
      string.format(
        "%s Failed.\nCodyResponse %s:\n\n %s",
        opts.message or "<not passed>",
        vim.inspect {
          current_file = vim.api.nvim_buf_get_name(0),
          buffers = vim.api.nvim_list_bufs(),
        },
        lines
      )
    )
  end

  a.it("should ask through chat what file we are in", function()
    execute_test_case { bang = false, file = "pool/pool.go" }
  end)

  a.it("should work after restarting", function()
    execute_test_case { bang = false, file = "pool/pool.go", message = "first" }

    -- Restart the server
    vim.cmd.CodyRestart()
    -- Wait for the server to be restarted
    vim.wait(100)

    execute_test_case { bang = true, file = "pool/pool_test.go", message = "second" }
  end)
end)

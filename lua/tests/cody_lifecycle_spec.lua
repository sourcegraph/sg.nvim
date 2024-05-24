vim.cmd [[runtime! after/plugin/cody.lua]]
vim.cmd [[runtime! after/plugin/cody-agent.lua]]

local rpc = assert(require "sg.cody.rpc", "able to load cody rpc")

local filter_msg = function(pred)
  return vim.tbl_filter(pred, rpc.messages)
end

local initialized = false
local find_initialized = function()
  return initialized
    and vim.tbl_filter(function(msg)
      return msg.type == "notify" and msg.method == "initialized"
    end, rpc.messages)[1]
end

local eq = assert.are.same
describe("Cody Lifecycle", function()
  before_each(function()
    require("sg").setup { enable_cody = true, accept_tos = true }

    require("sg.cody.rpc").start({}, function()
      initialized = true
    end)
  end)

  it("should handle file lifecycle", function()
    vim.wait(1000, find_initialized)

    vim.cmd.edit [[README.md]]

    local opened = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didOpen"
    end)[1]

    assert(
      opened,
      string.format(
        "Did not open readme: %s\n%s",
        vim.inspect(rpc.messages),
        vim.inspect(vim.tbl_map(function(k)
          return string.format("%s: %s", k, vim.api.nvim_buf_get_name(k))
        end, vim.api.nvim_list_bufs()))
      )
    )
    assert(string.find(opened.params.uri, "README.md"), "Did not send correct filename")

    local readme_bufnr = vim.api.nvim_get_current_buf()

    vim.cmd.edit [[Cargo.toml]]

    vim.wait(10)
    vim.api.nvim_buf_delete(readme_bufnr, { force = true })
    vim.wait(10)

    local deleted = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didClose"
    end)[1]

    assert(deleted, "Did not close readme")
    assert(string.find(deleted.params.uri, "README.md"), "Did not close correct filename")

    -- Update the buffer
    vim.wait(10)
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "inserted" })
    vim.wait(10)

    -- Wait til we get the notificaiton (it's debounced, so won't happen right away)
    vim.wait(10000, function()
      local changed = filter_msg(function(msg)
        return msg.type == "notify"
          and msg.method == "textDocument/didChange"
          and string.find(msg.params.uri, "Cargo.toml")
      end)[1]

      return changed ~= nil
    end, 10, false)
    vim.wait(10)

    local changed = filter_msg(function(msg)
      return msg.type == "notify"
        and msg.method == "textDocument/didChange"
        and string.find(msg.params.uri, "Cargo.toml")
    end)[1]

    assert(changed, "Did not receive didChange notification: " .. vim.inspect(rpc.messages))

    eq({ "inserted" }, vim.api.nvim_buf_get_lines(0, 0, 1, false))
    assert(
      string.find(changed.params.uri, "Cargo.toml"),
      "Did not update correct filename: " .. vim.inspect(changed)
    )
  end)
end)

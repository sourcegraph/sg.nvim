vim.cmd [[runtime! after/plugin/cody.lua]]
vim.cmd [[runtime! after/plugin/cody-agent.lua]]

require("plenary.async").tests.add_to_env()

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
describe("cody", function()
  before_each(function()
    require("sg.cody.rpc").start({}, function()
      initialized = true
    end)
  end)

  a.it("should have initialized", function()
    vim.wait(5000, find_initialized)

    local initialized = find_initialized()
    eq(initialized, { type = "notify", method = "initialized", params = {} })
  end)

  a.it("should be able to list recipes", function()
    vim.wait(5000, find_initialized)

    local err, chat_question
    rpc.execute.list_recipes(function(err_, data)
      err = err_

      chat_question = vim.tbl_filter(function(recipe)
        return recipe.id == "chat-question"
      end, data)[1]
    end)

    vim.wait(1000, function()
      return err or chat_question
    end, 5)

    eq(err, nil)
    eq(chat_question, { id = "chat-question", title = "Chat Question" })
  end)

  a.it("should handle file lifecycle", function()
    vim.cmd.edit [[README.md]]

    local opened = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didOpen"
    end)[1]

    assert(opened, "Did not open readme")
    assert(string.find(opened.params.filePath, "README.md"), "Did not send correct filename")

    local readme_bufnr = vim.api.nvim_get_current_buf()

    vim.cmd.edit [[Cargo.toml]]

    vim.wait(10)
    vim.api.nvim_buf_delete(readme_bufnr, { force = true })
    vim.wait(10)

    local deleted = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didClose"
    end)[1]

    assert(deleted, "Did not close readme")
    assert(string.find(deleted.params.filePath, "README.md"), "Did not close correct filename")

    -- Update the buffer
    vim.wait(10)
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "inserted" })
    vim.wait(10)

    -- Wait til we get the notificaiton (it's debounced, so won't happen right away)
    vim.wait(10000, function()
      local changed = filter_msg(function(msg)
        return msg.type == "notify"
          and msg.method == "textDocument/didChange"
          and string.find(msg.params.filePath, "Cargo.toml")
      end)[1]

      return changed ~= nil
    end, 10, false)
    vim.wait(10)

    local changed = filter_msg(function(msg)
      return msg.type == "notify"
        and msg.method == "textDocument/didChange"
        and string.find(msg.params.filePath, "Cargo.toml")
    end)[1]

    assert(changed, "Did not receive didChange notification: " .. vim.inspect(rpc.messages))

    eq({ "inserted" }, vim.api.nvim_buf_get_lines(0, 0, 1, false))
    assert(
      string.find(changed.params.filePath, "Cargo.toml"),
      "Did not update correct filename: " .. vim.inspect(changed)
    )
  end)
end)

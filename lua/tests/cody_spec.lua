-- For some reason this doesn't always get loaded?...
vim.cmd [[runtime! plugin/cody-agent.lua]]
-- local augroup_cody = vim.api.nvim_create_augroup("augroup-cody", { clear = false })

require("plenary.async").tests.add_to_env()

local rpc = assert(require "sg.cody.rpc", "able to load cody rpc")

local filter_msg = function(pred)
  return vim.tbl_filter(pred, rpc.messages)
end

local find_initialized = function()
  return vim.tbl_filter(function(msg)
    return msg.type == "notify" and msg.method == "initialized"
  end, rpc.messages)[1]
end

local eq = assert.are.same
describe("cody", function()
  a.it("should have initialized", function()
    vim.wait(1000, function()
      return find_initialized()
    end)

    local initialized = find_initialized()
    eq(initialized, { type = "notify", method = "initialized", params = {} })
  end)

  a.it("should be able to list recipes", function()
    vim.wait(1000, function()
      return find_initialized()
    end)

    local err, data = rpc.execute.list_recipes()
    eq(err, nil)

    local chat_question = vim.tbl_filter(function(recipe)
      return recipe.id == "chat-question"
    end, data)[1]

    eq(chat_question, { id = "chat-question", title = "chat-question" })
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

    vim.api.nvim_buf_delete(readme_bufnr, { force = true })

    local deleted = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didClose"
    end)[1]

    assert(deleted, "Did not close readme")
    assert(string.find(deleted.params.filePath, "README.md"), "Did not close correct filename")
  end)
end)

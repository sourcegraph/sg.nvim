print('[cody-spec]: nvim_cmd (progpath) =' .. vim.v.progpath)
print('[cody-spec]: nvim_cmds (argv) =' .. vim.inspect(vim.v.argv))
print('[cody-spec]: env.NVIM_SYSTEM_RPLUGIN_MANIFEST=' .. vim.env.NVIM_SYSTEM_RPLUGIN_MANIFEST)
print('[cody-spec]: cody-agent: ' .. require('sg.config').cody_agent)

-- local _ = require('sg.request').request
local _ = require('sg.vendored.vim-lsp-rpc')
local bin_sg_nvim = require("sg.config").get_nvim_agent()

-- For some reason this doesn't always get loaded?...
vim.cmd [[runtime! plugin/cody-agent.lua]]
-- local augroup_cody = vim.api.nvim_create_augroup("augroup-cody", { clear = false })

require("plenary.async").tests.add_to_env()

local async_util = require "plenary.async.util"

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
    vim.wait(2000, function()
      return find_initialized()
    end, 10)

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

    async_util.scheduler()
    vim.api.nvim_buf_delete(readme_bufnr, { force = true })
    async_util.scheduler()

    local deleted = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didClose"
    end)[1]

    assert(deleted, "Did not close readme")
    assert(string.find(deleted.params.filePath, "README.md"), "Did not close correct filename")

    -- Update the buffer
    async_util.scheduler()
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "inserted" })
    async_util.scheduler()

    -- Wait til we get the notificaiton (it's debounced, so won't happen right away)
    vim.wait(10000, function()
      local changed = filter_msg(function(msg)
        return msg.type == "notify" and msg.method == "textDocument/didChange"
      end)[1]

      return changed ~= nil
    end, 10, false)
    async_util.scheduler()

    local changed = filter_msg(function(msg)
      return msg.type == "notify" and msg.method == "textDocument/didChange"
    end)[1]

    eq({ "inserted" }, vim.api.nvim_buf_get_lines(0, 0, 1, false))
    assert(string.find(changed.params.filePath, "Cargo.toml"), "Did not update correct filename")
  end)
end)

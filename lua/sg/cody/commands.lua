---@tag cody.lua-commands
---@config { module = "sg.cody.commands" }

local auth = require "sg.auth"
local chat = require "sg.cody.rpc.chat"
local util = require "sg.utils"

local Message = require "sg.cody.message"
local protocol = require "sg.cody.protocol"
local CodySpeaker = require("sg.types").CodySpeaker

local commands = {}

--- Ask Cody a question, without any selection
---@param message string[]
---@param opts? cody.ChatOpts
commands.ask = function(message, opts)
  local contents = vim.tbl_flatten(message)

  chat.new(opts, function(_, id)
    chat.submit_message(id, Message.init(CodySpeaker.human, contents):to_submit_message())
  end)
end

--- Ask Cody about the selected code
---@param bufnr number
---@param start_row number
---@param end_row number
---@param message string
---@param opts cody.ChatOpts
commands.ask_range = function(bufnr, start_row, end_row, message, opts)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  local contents = vim.tbl_flatten {
    message,
    "",
    util.format_code(bufnr, selection),
  }

  chat.new(opts, function(_, id)
    chat.submit_message(id, Message.init(CodySpeaker.human, contents):to_submit_message())
  end)
end

--- Send an autocomplete request
---@param request { filename: string, row: number, col: number }?
---@param callback function(err: table, data: CodyAutocompleteResult)
commands.autocomplete = function(request, callback)
  if not request then
    request = {}
    request.filename = vim.api.nvim_buf_get_name(0)
    request.row, request.col = unpack(vim.api.nvim_win_get_cursor(0))
  end

  local doc = protocol.get_text_document(0)
  require("sg.cody.rpc").notify("textDocument/didChange", doc)
  require("sg.cody.rpc").execute.autocomplete(
    request.filename,
    request.row - 1,
    request.col,
    callback
  )
end

--- Open a cody chat
---
--- To configure keymaps, you can do something like:
---
--- This will disable <c-c> in insert mode from getting
--- mapped by Cody.
---
--- <code=lua>
---   require("sg.cody.commands").chat(true, {
---     keymaps = {
---       i = {
---         ["<c-c>"] = false,
---       },
---     },
---   })
--- </code>
---
--- Additionally, you can map more functionality like so:
---
--- <code=lua>
---   require("sg.cody.commands").chat(true, {
---     keymaps = {
---       i = {
---         ["hello"] = { "Says Hello", function(chat) print("hello") end },
---       },
---     },
---   })
--- </code>
---
---@param new boolean
---@param opts cody.ChatOpts
commands.chat = function(new, opts)
  opts = opts or {}

  if new then
    require("sg.cody.rpc.chat").new(opts)
  else
    require("sg.cody.rpc.chat").open_or_new(opts)
  end
end

--- Toggle a Cody chat
commands.toggle = function(opts)
  require("sg.cody.rpc.chat").toggle(opts)
end

--- Ask Cody to preform a task on the selected code.
---@param bufnr number
---@param start_line number
---@param end_line number
---@param message string
commands.do_task = function(bufnr, start_line, end_line, message)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local formatted = util.format_code(bufnr, selection)

  local prompt = message
  prompt = prompt .. "\nReply only with code, nothing else. Enclose it in a markdown style block.\n"
  prompt = prompt .. table.concat(formatted, "\n")

  local rpc = require "sg.cody.rpc"
  rpc.request("chat/new", nil, function(err, id)
    if err then
      vim.notify(err)
      return
    end

    require("sg.cody.tasks").init {
      id = id,
      bufnr = bufnr,
      task = prompt,
      start_row = start_line,
      end_row = end_line,
    }
  end)
end

--- Open a selection to get an existing Cody conversation
commands.history = function()
  error "NOT YET IMPLEMENTED. PLEASE REPORT IF YOU WERE USING THIS"
end

--- Focus the currently active history window.
---
--- Can be set to a keymap by:
--- <code=lua>
---   vim.keymap.set('n', '<leader>ch', function()
---     require("sg.cody.commands").focus_history()
---   end)
--- </code>
commands.focus_history = function()
  local active = require("sg.cody.rpc.chat").get_last_chat()
  if not active then
    return
  end

  local win = active.windows.history_win
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  return vim.api.nvim_set_current_win(win)
end

--- Focus the currently active prompt.
---
--- Can be set to a keymap by:
--- <code=lua>
---   vim.keymap.set('n', '<leader>cp', function()
---     require("sg.cody.commands").focus_prompt()
---   end)
--- </code>
commands.focus_prompt = function()
  local active = require("sg.cody.rpc.chat").get_last_chat()
  if not active then
    return
  end

  local win = active.windows.prompt_win
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  return vim.api.nvim_set_current_win(win)
end

-- Wrap all commands with making sure TOS is accepted
for key, value in pairs(commands) do
  commands[key] = function(...)
    if not auth.get() then
      vim.notify "You are not logged in to Sourcegraph. Use `:SourcegraphLogin` or `:help sg` to log in"
      return
    end

    return value(...)
  end
end

return commands

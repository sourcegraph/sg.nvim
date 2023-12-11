---@tag cody.lua-commands
---@config { module = "sg.cody.commands" }

local auth = require "sg.auth"
local util = require "sg.utils"

local CodyBase = require "sg.components.layout.base"
local CodyFloat = require "sg.components.layout.float"
local CodySplit = require "sg.components.layout.split"
local CodyHover = require "sg.components.layout.hover"
local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"
local protocol = require "sg.cody.protocol"

local commands = {}

--- Ask Cody a question, without any selection
---@param message string[]
commands.ask = function(message)
  local layout = CodySplit.init {}

  local contents = vim.tbl_flatten(message)
  layout:request_user_message(contents)
end

--- Ask Cody about the selected code
---@param bufnr number
---@param start_row number
---@param end_row number
---@param message string
commands.ask_range = function(bufnr, start_row, end_row, message)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  local layout = CodySplit.init {}

  local contents = vim.tbl_flatten {
    message,
    "",
    util.format_code(bufnr, selection),
  }

  layout:request_user_message(contents)
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
  require("sg.cody.rpc").execute.autocomplete(request.filename, request.row - 1, request.col, callback)
end

--- Ask Cody about the selected code
---@param bufnr number
---@param start_line number
---@param end_line number
---@param message string
commands.float = function(bufnr, start_line, end_line, message)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local layout = CodyHover.init { name = message, bufnr = bufnr, start_line = start_line, end_line = end_line }

  local contents = vim.tbl_flatten {
    message,
    "",
    util.format_code(bufnr, selection),
  }

  layout:request_user_message(contents)
end

--- Start a new CodyChat
---@param name string?
---@param opts { reset: boolean }?
---@return CodyLayoutSplit
commands.chat = function(name, opts)
  opts = opts or {}

  -- TODO: Config for this :)
  local layout = CodySplit.init { name = name, reset = opts.reset }
  layout:show()

  return layout
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
  prompt = prompt .. "\nReply only with code, nothing else\n"
  prompt = prompt .. table.concat(formatted, "\n")

  return require("sg.cody.tasks").init {
    bufnr = bufnr,
    task = prompt,
    start_row = start_line,
    end_row = end_line,
  }
end

--- Open a selection to get an existing Cody conversation
commands.history = function()
  local states = State.history()

  vim.ui.select(states, {
    prompt = "Cody History: ",
    format_item = function(state)
      return string.format("%s (%d)", state.name, #state.messages)
    end,
  }, function(state)
    vim.schedule(function()
      local layout = CodyFloat.init { state = state }
      layout:show()
    end)
  end)
end

--- Add context to an existing state
---@param start_line any
---@param end_line any
---@param state CodyState?
commands.add_context = function(bufnr, start_line, end_line, state)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local content = vim.tbl_flatten {
    "Some additional context is:",
    util.format_code(bufnr, selection),
  }

  -- TODO: We should be re-rendering when we see this happen
  if not state then
    state = State.last()
  end
  state:append(Message.init(Speaker.user, content, {}))
end

commands.toggle = function()
  CodySplit:toggle()
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
  local active = CodyBase:get_active()
  if not active then
    return
  end

  local win = active.history.win
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
  local active = CodyBase:get_active()
  if not active then
    return
  end

  if not active.prompt then
    return
  end

  local win = active.prompt.win
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  -- ??
  -- vim.cmd [[startinsert]]

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

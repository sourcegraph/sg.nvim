local log = require "sg.log"

local Speaker = require "sg.cody.speaker"
local Message = require "sg.cody.message"
local Typewriter = require "sg.components.typewriter"
local Mark = require "sg.mark"

local state_history = {}

local last_state = nil
local set_last_state = function(state)
  last_state = state
end

---@class CodyMessageState
---@field message CodyMessage
---@field mark CodyMarkWrapper
---@field typewriter CodyTypewriter?

---@class CodyStateOpts
---@field name string?
---@field code_only boolean?

---@class CodyState
---@field name string
---@field code_only boolean
---@field messages CodyMessageState[]
local State = {}
State.__index = State

function State.init(opts)
  local self = setmetatable({
    name = opts.name or tostring(#state_history),
    code_only = opts.code_only,
    messages = {},
  }, State)

  table.insert(state_history, self)
  set_last_state(self)

  return self
end

function State.history()
  return state_history
end

function State.last()
  return last_state
end

--- Add a new message and return its id
---@param message CodyMessage
---@return number
function State:append(message)
  set_last_state(self)

  -- If the message is from the user, then we want to type it out very quickly
  local interval
  if message.speaker == Speaker.user then
    interval = 1
  end

  table.insert(self.messages, {
    message = message,
    extmark = nil,
    typewriter = Typewriter.init {
      interval = interval,
    },
  })

  return #self.messages
end

--- Replace the message with the provided id with the new message
---@param id number
---@param message CodyMessage
function State:update_message(id, message)
  set_last_state(self)

  self.messages[id].message = message
end

function State:mark_message_complete(id)
  self.messages[id].message:mark_complete()
end

--- Get a new completion, based on the state
---@param bufnr number
---@param win number
---@param callback CodyChatCallbackHandler
---@return number: message ID where completion will happen
function State:complete(bufnr, win, callback)
  set_last_state(self)

  local snippet = table.concat(self.messages[#self.messages].message.msg, "\n") .. "\n"

  self:render(bufnr, win)
  vim.cmd [[mode]]

  -- Draw the "Loading" before sending a request
  local id = self:append(Message.init(Speaker.cody, { "Loading ..." }, {}))
  self:render(bufnr, win)

  -- Execute chat question. Will be completed async
  if self.code_only then
    require("sg.cody.rpc").execute.code_question(snippet, callback(id))
  else
    require("sg.cody.rpc").execute.chat_question(snippet, callback(id))
  end

  return id
end

--- Render the state to a buffer and window
---@param bufnr number
---@param win number
function State:render(bufnr, win)
  log.debug "state:render"

  -- Keep track of how many messages have been renderd
  local rendered = 0

  --- Render a message
  ---@param message_state CodyMessageState
  local render_one_message = function(message_state)
    local message = message_state.message
    if message.hidden then
      return
    end

    if not message_state.mark or message_state.mark.bufnr ~= bufnr then
      -- Put a blank line between different marks
      if rendered >= 1 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "" })
      end

      -- Create a new extmark associated in the last line
      local last_line = vim.api.nvim_buf_line_count(bufnr) - 1
      message_state.mark = Mark.init {
        ns = Typewriter.ns,
        bufnr = bufnr,
        start_row = last_line,
        start_col = 0,
        end_row = last_line,
        end_col = 0,
      }
    end

    -- If the message has already been completed, then we can just display it immediately.
    --  This prevents typewriter from typing everything out all the time when you do something like
    --  toggle the previous chat
    local interval
    if message.completed then
      interval = 0
    end

    local text = vim.trim(table.concat(message:render(), "\n"))
    message_state.typewriter:set_text(text)
    message_state.typewriter:render(bufnr, win, message_state.mark, { interval = interval })

    rendered = rendered + 1
  end

  for _, message_state in ipairs(self.messages) do
    render_one_message(message_state)
  end
end

return State

local Speaker = require "sg.cody.speaker"
local Message = require "sg.cody.message"

local state_history = {}

local last_state = nil
local set_last_state = function(state)
  last_state = state
end

---@class CodyStateOpts
---@field name string?

---@class CodyState
---@field name string
---@field messages CodyMessage[]
local State = {}
State.__index = State

function State.init(opts)
  local self = setmetatable({
    name = opts.name or tostring(#state_history),
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

--- Add a new message
---@param message CodyMessage
function State:append(message)
  set_last_state(self)

  table.insert(self.messages, message)
end

--- Update the last message
--- TODO: Should add a filter or some way to track the message down
---@param message CodyMessage
function State:update_message(message)
  set_last_state(self)

  if not vim.tbl_isempty(self.messages) then
    self.messages[#self.messages] = message
  else
    self:append(message)
  end
end

--- Get a new completion, based on the state
---@param bufnr number
---@param win number
function State:complete(bufnr, win)
  set_last_state(self)

  local snippet = ""
  for _, message in ipairs(self.messages) do
    if message.speaker == Speaker.user then
      snippet = snippet .. table.concat(message.msg, "\n") .. "\n"
    end
  end

  self:append(Message.init(Speaker.system, { "Loading ... " }, { ephemeral = true }))
  self:render(bufnr, win)
  vim.cmd [[mode]]

  local completion = require("sg.cody.rpc").execute.chat_question(snippet)
  -- self:append(Message.init(Speaker.cody, vim.split(vim.trim(completion), "\n")))
  -- self:render(bufnr, win)
end

--- Render the state to a buffer and window
---@param bufnr number
---@param win number
function State:render(bufnr, win)
  -- TODO: It should be possible to not wipe away the whole buffer... we
  -- need to start marking where regions start with extmarks, find the last one
  -- that wasn't a ephemeral, and then render the rest?
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  -- TODO: Don't waste the first line, that's gross
  local messages = {}
  for _, message in ipairs(self.messages) do
    local rendered = message:render()
    if not vim.tbl_isempty(rendered) then
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, rendered)
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
    end

    if not message.ephemeral then
      table.insert(messages, message)
    end
  end

  self.messages = messages

  local linecount = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(win, { linecount, 0 })
end

return State

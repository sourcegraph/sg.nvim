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

  if not vim.tbl_isempty(self.messages) and self.messages[#self.messages].speaker ~= Speaker.user then
    self.messages[#self.messages] = message
  else
    self:append(message)
  end
end

--- Get a new completion, based on the state
---@param bufnr number
---@param win number
---@param code_only boolean
---@param callback function(noti)
function State:complete(bufnr, win, code_only, callback)
  set_last_state(self)

  local snippet = ""
  for _, message in ipairs(self.messages) do
    if message.speaker == Speaker.user then
      snippet = snippet .. table.concat(message.msg, "\n") .. "\n"
    end
  end

  self:append(Message.init(Speaker.system, { "Loading ... " }, {}, { ephemeral = true }))
  self:render(bufnr, win)
  vim.cmd [[mode]]

  -- Execute chat question. Will be completed async
  if code_only then
    require("sg.cody.rpc").execute.code_question(snippet, callback)
  else
    require("sg.cody.rpc").execute.chat_question(snippet, callback)
  end
end

--- Render the state to a buffer and window
---@param bufnr number
---@param win number
function State:render(bufnr, win)
  -- TODO: It should be possible to not wipe away the whole buffer... we
  -- need to start marking where regions start with extmarks, find the last one
  -- that wasn't a ephemeral, and then render the rest?
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local messages = {}
  local rendered_lines = {}
  for _, message in ipairs(self.messages) do
    if #rendered_lines > 0 then
      table.insert(rendered_lines, "")
    end
    for _, line in ipairs(message:render()) do
      if not vim.tbl_isempty(rendered_lines) or line ~= "" then
        if message.speaker == Speaker.cody then
          -- Cody has a tendency to have random trailing white space
          line = line:gsub("%s+$", "")
          table.insert(rendered_lines, line)
        else
          table.insert(rendered_lines, line)
        end
      end
    end

    if not message.ephemeral then
      table.insert(messages, message)
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, rendered_lines)
  self.messages = messages

  local linecount = vim.api.nvim_buf_line_count(bufnr)
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
    vim.api.nvim_win_set_cursor(win, { linecount, 0 })
  end
end

return State

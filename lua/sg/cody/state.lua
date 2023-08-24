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

--- Add a new message and return its id
---@param message CodyMessage
---@return number
function State:append(message)
  set_last_state(self)

  table.insert(self.messages, message)
  return #self.messages
end

--- Replace the message with the provided id with the new message
---@param id number
---@param message CodyMessage
function State:update_message(id, message)
  set_last_state(self)

  self.messages[id] = message
end

---@class CompleteOpts
---@field code_only boolean

--- Get a new completion, based on the state
---@param bufnr number
---@param win number
---@param callback CodyChatCallbackHandler
---@param opts CompleteOpts?
---@return number: message ID where completion will happen
function State:complete(bufnr, win, callback, opts)
  set_last_state(self)

  local snippet = table.concat(self.messages[#self.messages].msg, "\n") .. "\n"

  self:render(bufnr, win)
  vim.cmd [[mode]]

  local id = self:append(Message.init(Speaker.cody, { "Loading ..." }, {}))
  -- Execute chat question. Will be completed async
  if opts and opts.code_only then
    require("sg.cody.rpc").execute.code_question(snippet, callback(id))
  else
    require("sg.cody.rpc").execute.chat_question(snippet, callback(id))
  end

  return id
end

--- Render the state to a buffer and window
---@param bufnr number
---@param win number
---@param s number?: The first message id to render.
---@param e number?: The last message id to render.
function State:render(bufnr, win, s, e)
  -- TODO: It should be possible to not wipe away the whole buffer... we
  -- need to start marking where regions start with extmarks, find the last one
  -- that wasn't a ephemeral, and then render the rest?
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local rendered_lines = {}
  for _, message in ipairs { unpack(self.messages, s, e) } do
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
  end

  local first_line = rendered_lines[1]
  if first_line:sub(1, 3) == "```" then
    local lang = first_line:sub(4)
    vim.bo[bufnr].filetype = lang
    rendered_lines = { unpack(rendered_lines, 2, #rendered_lines - 1) }
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, rendered_lines)

  local linecount = vim.api.nvim_buf_line_count(bufnr)
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
    vim.api.nvim_win_set_cursor(win, { linecount, 0 })
  end
end

return State

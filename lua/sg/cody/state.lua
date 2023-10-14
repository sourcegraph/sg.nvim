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

---@class CodyState
---@field name string
---@field messages CodyMessageState[]
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

  table.insert(self.messages, {
    message = message,
    extmark = nil,
    typewriter = Typewriter.init(),
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

function State:_update_text()
  local rendered_lines = {}
  for _, message_state in ipairs(self.messages) do
    local message = message_state.message

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

  -- if #rendered_lines > 0 then
  --   local first_line = rendered_lines[1]
  --   if first_line:sub(1, 3) == "```" then
  --     local lang = first_line:sub(4)
  --     vim.bo[bufnr].filetype = lang
  --     rendered_lines = { unpack(rendered_lines, 2, #rendered_lines - 1) }
  --   end
  -- end
end

-- TODO: I would like to move code_only into the state.
--          The state cannot switch between code_only and not code_only
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

  local snippet = table.concat(self.messages[#self.messages].message.msg, "\n") .. "\n"

  self:render(bufnr, win)
  vim.cmd [[mode]]

  -- Draw the "Loading" before sending a request
  local id = self:append(Message.init(Speaker.cody, { "Loading ..." }, {}))
  self:render(bufnr, win)

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
---@param render_opts CodyLayoutRenderOpts?
function State:render(bufnr, win, render_opts)
  log.debug "state:render"

  --- Render a message
  ---@param message_state CodyMessageState
  local render_one_message = function(message_state)
    local message = message_state.message
    if message.hidden then
      return
    end

    if not message_state.mark then
      -- Put a new line at the end of the buffer
      if vim.api.nvim_buf_line_count(bufnr) > 1 then
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

    message_state.typewriter:set_text(table.concat(message:render(), "\n"))
    message_state.typewriter:render(bufnr, win, message_state.mark)
  end

  for _, message_state in ipairs(self.messages) do
    render_one_message(message_state)
  end
end

return State

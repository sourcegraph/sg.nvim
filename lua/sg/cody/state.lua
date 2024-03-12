local log = require "sg.log"

local Mark = require "sg.mark"
local Transcript = require "sg.cody.transcript"
local Typewriter = require "sg.components.typewriter"

local state_history = {}

local last_state = nil
local set_last_state = function(state)
  last_state = state
end

---@class cody.StateOpts
---@field id string: ID sent from cody-agent
---@field name? string
---@field code_only? boolean

---@class cody.State
---@field id string: chat ID (from cody-agent)
---@field name string
---@field transcript sg.cody.Transcript
---@field models cody.ChatModelProvider[]
---@field code_only boolean: TODO: think about how we could do this better...
local State = {}
State.__index = State

--- Create a new state
---@param opts cody.StateOpts
---@return cody.State
function State.init(opts)
  local self = setmetatable({
    id = assert(opts.id, "[cody.state] must pass an ID"),
    name = opts.name or tostring(#state_history),
    transcript = nil,

    -- TODO: delete?
    code_only = opts.code_only,
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
---@param message sg.cody.Message
function State:submit(message, callback)
  set_last_state(self)

  callback = callback or function() end
  require("sg.cody.rpc.chat").submit_message(self.id, message:to_submit_message(), callback)
end

--- Update the transcript
---@param transcript cody.ExtensionTranscriptMessage
function State:update_transcript(transcript)
  if not self.transcript then
    self.transcript = Transcript.of_agent_transcript(transcript)
  else
    self.transcript:update(transcript)
  end
end

--- Get a new completion, based on the state
---@param bufnr number
---@param win number
function State:complete(bufnr, win, callback)
  set_last_state(self)
  callback = callback or function() end

  self:render(bufnr, win)
  vim.cmd [[mode]]

  self:submit(self.transcript:last_message(), function(err, data)
    -- TODO: UPDATE TRANSCRIPT HERE!
    print("MESS COMPLETED:", vim.inspect(err), vim.inspect(data))
    callback()
  end)

  -- Execute chat question. Will be completed async
  if self.code_only then
    -- require("sg.cody.rpc").execute.code_question(snippet, callback(id))
    -- return function(msg)
    --   if not msg then
    --     return
    --   end
    --
    --   local lines = vim.split(msg.text or "", "\n")
    --   if self.code_only then
    --     -- Only get the lines between ```
    --     local render_lines = {}
    --     for _, line in ipairs(lines) do
    --       if vim.trim(line) == "```" then
    --         require("sg.cody.rpc").message_callbacks[msg.data.id] = nil
    --       elseif not vim.startswith(line, "```") then
    --         table.insert(render_lines, line)
    --       end
    --     end
    --
    --     self.state:update_message(id, Message.init(Speaker.cody, render_lines))
    --   else
    --     self.state:update_message(id, Message.init(Speaker.cody, lines))
    --   end
    --   self:render()
    -- end
    error "got to code only"
  else
  end
end

--- Render the state to a buffer and window
---@param bufnr number
---@param win number
function State:render(bufnr, win)
  log.trace "state:render"

  if not self.transcript then
    log.debug "state:no-transcript"
    return
  end

  if self.models then
    -- vim.notify "YO THIS ONE HAS MODELS"
  end

  -- Keep track of how many messages have been renderd
  local rendered = 0

  --- Render a message
  ---@param idx number
  ---@param message_state sg.cody.transcript.MessageWrapper
  local render_one_message = function(idx, message_state)
    local message = message_state.message
    if message.hidden then
      return
    end

    if not message_state.mark or not message_state.mark:valid(bufnr) then
      -- Put a blank line between different marks
      if rendered >= 1 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "" })
      end

      -- Create a new extmark associated in the last line
      local last_line = vim.api.nvim_buf_line_count(bufnr) - 1
      message_state = self.transcript:set_mark(
        idx,
        Mark.init {
          ns = Typewriter.ns,
          bufnr = bufnr,
          start_row = last_line,
          start_col = 0,
          end_row = last_line,
          end_col = 0,
        }
      )
    end

    -- If the message has already been completed, then we can just display it immediately.
    --  This prevents typewriter from typing everything out all the time when you do something like
    --  toggle the previous chat
    local interval
    if not self.transcript:is_message_in_progress() then
      interval = 0
    end

    local text = vim.trim(table.concat(message:render(), "\n"))
    message_state.typewriter:set_text(text)
    message_state.typewriter:render(bufnr, win, message_state.mark, { interval = interval })

    rendered = rendered + 1

    -- /!\ TODO investigate, this is crude fix. 
    -- Basically, the messages the user type are marked as completed, but the answers from Cody
    -- are never marked as such even after being displayed. Forcing it to true fixes it.
    message.completed = true
  end

  for i = 1, self.transcript:length() do
    render_one_message(i, self.transcript:get_message(i))
  end
end

function State:set_models(models)
  self.models = models
end

return State

local log = require "sg.log"

local rpc = require "sg.rpc"

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

function State:complete(bufnr)
  set_last_state(self)

  local snippet = ""
  for _, message in ipairs(self.messages) do
    if message.speaker == Speaker.user then
      snippet = snippet .. table.concat(message.msg, "\n") .. "\n"
    end
  end

  self:append(Message.init(Speaker.system, { "Loading ... " }, { ephemeral = true }))
  self:render(bufnr)
  vim.cmd [[mode]]

  local completion = rpc.complete(snippet)
  self:append(Message.init(Speaker.cody, vim.split(vim.trim(completion), "\n")))
  self:render(bufnr)
end

function State:render(bufnr)
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
end

return State

local log = require "sg.log"

local rpc = require "sg.rpc"

local Speaker = require "sg.cody.speaker"
local Message = require "sg.cody.message"

---@class CodyState
---@field messages CodyMessage[]
local State = {}
State.__index = State

function State.init()
  return setmetatable({
    messages = {},
  }, State)
end

--- Add a new message
---@param message CodyMessage
function State:append(message)
  table.insert(self.messages, message)
end

function State:complete(bufnr)
  local snippet = ""
  for _, message in ipairs(self.messages) do
    if message.speaker == Speaker.user then
      snippet = snippet .. table.concat(message.msg, "\n") .. "\n"
    end
  end

  self:append(Message.init(Speaker.system, { "Loading ... " }, { ephemeral = true }))
  self:render(bufnr)
  vim.cmd [[mode]]

  print "starting completion"
  log.info "starting completion"
  local completion = rpc.complete(snippet)
  print "done with completion"
  self:append(Message.init(Speaker.cody, vim.split(vim.trim(completion), "\n")))
  self:render(bufnr)
end

function State:render(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  -- TODO: Don't waste the first line, that's gross
  local messages = {}
  for _, message in ipairs(self.messages) do
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, message:render())
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })

    if not message.ephemeral then
      table.insert(messages, message)
    end
  end

  self.messages = messages
end

return State

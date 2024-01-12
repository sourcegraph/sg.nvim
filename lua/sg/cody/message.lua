local types = require "sg.types"
local utils = require "sg.utils"
local CodySpeaker = types.CodySpeaker

---@class sg.cody.Message
---@field message cody.ChatMessage
---@field hidden boolean
local Message = {}
Message.__index = Message

---@class cody.Message.initOptions
---@field hidden? boolean
---@field contextFiles? cody.ContextFile[]

--- Create a new message
---@param speaker cody.Speaker
---@param text string | string[]
---@param opts? cody.Message.initOptions
---@return sg.cody.Message
function Message.init(speaker, text, opts)
  opts = opts or {}

  assert(CodySpeaker[speaker], string.format("Invalid speaker: %s", vim.inspect(speaker)))

  if type(text) == "table" then
    text = table.concat(text, "\n")
  end
  assert(type(text) == "string", string.format("Invalid text: %s", vim.inspect(text)))

  return setmetatable({
    message = {
      speaker = speaker,
      displayText = text,
      text = text,
      contextFiles = opts.contextFiles,
    },
    hidden = opts.hidden,
  }, Message)
end

--- Create a new message from a chat message
---@param message cody.ChatMessage
---@return sg.cody.Message
function Message.of_agent_message(message)
  if message.displayText and message.speaker == CodySpeaker.human then
    message.displayText = utils.replace_markdown_link(message.displayText)
  end

  return setmetatable({
    message = message,
    hidden = false,
  }, Message)
end

---@return Cody.ChatWebviewMessage.submit
function Message:to_submit_message(opts)
  opts = opts or {}
  if opts.addEnhancedContext == nil then
    opts.addEnhancedContext = true
  end

  ---@type Cody.ChatWebviewMessage.submit
  return {
    command = "submit",
    text = self:text(),
    submitType = "user",
    addEnhancedContext = opts.addEnhancedContext,
    contextFiles = {},
  }
end

--- Get the current text of the message (always returns a string)
---@return string
function Message:text()
  return self.message.displayText or self.message.text or ""
end

--- Render a message to its corresponding lines
---@return string[]
function Message:render()
  if self.hidden then
    return {}
  end

  local lines = vim.split(self:text(), "\n")
  if self.message.speaker == CodySpeaker.assistant then
    local out = {}
    if self.message.contextFiles and #self.message.contextFiles > 0 then
      table.insert(out, "{{{ " .. tostring(#self.message.contextFiles) .. " context files")
      for _, v in ipairs(self.message.contextFiles) do
        table.insert(out, "- " .. v.fileName)
      end
      table.insert(out, "}}}")
      table.insert(out, "")
    end

    for _, line in ipairs(lines) do
      table.insert(out, line)
    end
    return out
  elseif self.message.speaker == CodySpeaker.human then
    return vim.tbl_map(function(row)
      return "> " .. row
    end, lines)
  else
    return lines
  end
end

return Message

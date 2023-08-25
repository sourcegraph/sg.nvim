local Speaker = require "sg.cody.speaker"

---@class CodyMessage
---@field speaker CodySpeaker
---@field msg string[]
---@field hidden boolean
---@field contextFiles CodyContextFile[]?
local Message = {}
Message.__index = Message

---comment
---@param speaker CodySpeaker
---@param msg string[]
---@param contextFiles CodyContextFile[]?
---@param opts { hidden: boolean? }?
---@return CodyMessage
function Message.init(speaker, msg, contextFiles, opts)
  opts = opts or {}

  return setmetatable({
    speaker = speaker,
    msg = msg,
    contextFiles = contextFiles,
    hidden = opts.hidden or false,
  }, Message)
end

---@return string[]
function Message:render()
  if self.hidden then
    return {}
  end

  if self.speaker == Speaker.cody then
    local out = {}
    if self.contextFiles and #self.contextFiles > 0 then
      table.insert(out, "{{{ " .. tostring(#self.contextFiles) .. " context files")
      for _, v in ipairs(self.contextFiles) do
        table.insert(out, "- " .. v.fileName)
      end
      table.insert(out, "}}}")
      table.insert(out, "")
    end

    for _, line in ipairs(self.msg) do
      table.insert(out, line)
    end
    return out
  elseif self.speaker == Speaker.user then
    return vim.tbl_map(function(row)
      return "> " .. row
    end, self.msg)
  else
    return self.msg
  end
end

return Message

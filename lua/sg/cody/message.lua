local Speaker = require "sg.cody.speaker"

---@class CodyMessage
---@field speaker CodySpeaker
---@field msg string[]
---@field ephemeral boolean
---@field hidden boolean
local Message = {}
Message.__index = Message

---comment
---@param speaker CodySpeaker
---@param msg string[]
--- @param opts { ephemeral?:  boolean; hidden?: boolean }?
---@return CodyMessage
function Message.init(speaker, msg, opts)
  opts = opts or {}

  return setmetatable({
    speaker = speaker,
    msg = msg,
    hidden = opts.hidden or false,
    ephemeral = opts.ephemeral or false,
  }, Message)
end

---@return string[]
function Message:render()
  if self.hidden then
    return {}
  end

  if self.speaker == Speaker.cody then
    return self.msg
  elseif self.speaker == Speaker.user then
    return { "", unpack(vim.tbl_map(function(row)
      return "> " .. row
    end, self.msg)), "" }
  else
    return vim.tbl_map(function(row)
      return "system: " .. row
    end, self.msg)
  end
end

return Message

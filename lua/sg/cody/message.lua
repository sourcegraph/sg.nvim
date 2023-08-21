local Speaker = require "sg.cody.speaker"

---@class CodyMessage
---@field speaker CodySpeaker
---@field msg string[]
---@field ephemeral boolean
---@field hidden boolean
---@field contextFiles string[]
local Message = {}
Message.__index = Message

---comment
---@param speaker CodySpeaker
---@param msg string[]
---@param contextFiles string[]?
--- @param opts { ephemeral?:  boolean; hidden?: boolean }?
---@return CodyMessage
function Message.init(speaker, msg, contextFiles, opts)
  opts = opts or {}

  return setmetatable({
    speaker = speaker,
    msg = msg,
    contextFiles = contextFiles,
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
    local out = {}
    if #self.contextFiles > 0 then
      table.insert(out, "```")
      table.insert(out, "# Cody read the following files")
      for _, v in ipairs(self.contextFiles) do
        table.insert(out, "- " .. v)
      end
      table.insert(out, "```")
      table.insert(out, "")
    end
    for _, v in ipairs(self.msg) do
      table.insert(out, v)
    end
    return out
  elseif self.speaker == Speaker.user then
    return vim.tbl_map(function(row)
      return "> " .. row
    end, self.msg)
  else
    return vim.tbl_map(function(row)
      return "system: " .. row
    end, self.msg)
  end
end

return Message

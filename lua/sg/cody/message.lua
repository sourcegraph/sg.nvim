local Speaker = require "sg.cody.speaker"

---@class CodyMessage
---@field speaker CodySpeaker
---@field msg string[]
---@field ephemeral boolean
---@field hidden boolean
---@field contextFiles CodyContextFile[]?
local Message = {}
Message.__index = Message

---comment
---@param speaker CodySpeaker
---@param msg string[]
---@param contextFiles CodyContextFile[]?
---@param opts { ephemeral?: boolean; hidden?: boolean }?
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
function Message:render_context()
  if self.speaker ~= Speaker.cody or self.hidden then
    return {}
  end

  local out = {}
  if #self.contextFiles > 0 then
    table.insert(out, "{{{ " .. tostring(#self.contextFiles) .. " context files")
    for _, v in ipairs(self.contextFiles) do
      table.insert(out, "- " .. v.fileName)
    end
    table.insert(out, "}}}")
    table.insert(out, "")
  end
  return out
end

---@return string[]
function Message:render()
  if self.hidden then
    return {}
  end

  if self.speaker == Speaker.cody then
    return self.msg
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

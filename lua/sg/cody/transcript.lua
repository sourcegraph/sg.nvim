local Typewriter = require "sg.components.typewriter"
local Message = require "sg.cody.message"

---@class sg.cody.transcript.MessageWrapper
---@field message sg.cody.Message
---@field mark CodyMarkWrapper
---@field typewriter CodyTypewriter?

---@class sg.cody.Transcript
---@field messages sg.cody.Message[]
---@field typewriters CodyTypewriter[]
---@field marks CodyMarkWrapper[]
---@field _transcript cody.ExtensionTranscriptMessage
local Transcript = {}
Transcript.__index = Transcript

--- Turn agent transcript into one that we can manage
---@param transcript cody.ExtensionTranscriptMessage
---@return sg.cody.Transcript
function Transcript.of_agent_transcript(transcript)
  local transcript_messages = transcript.messages

  ---@type sg.cody.Message[]
  local messages = vim.tbl_map(Message.of_agent_message, transcript_messages)

  return setmetatable({
    -- Save this, just in case we need to set it later.
    _transcript = transcript,

    messages = messages,
    isMessageInProgress = transcript.isMessageInProgress,

    typewriters = {},
    marks = {},
  }, Transcript)
end

function Transcript:update(transcript)
  self._transcript = transcript

  local messages = vim.tbl_map(Message.of_agent_message, transcript.messages)
  self.messages = messages

  -- TODO: Delete other typewriters?
end

function Transcript:length()
  return #self.messages
end

--- Get a message (TODO: This could an iterable instead?)
---@param idx any
---@return sg.cody.transcript.MessageWrapper
function Transcript:get_message(idx)
  local interval

  if not self.typewriters[idx] then
    self.typewriters[idx] = Typewriter.init {
      transcript = self,
      interval = interval,
    }
  end

  ---@type sg.cody.transcript.MessageWrapper
  return {
    message = self.messages[idx],
    mark = self.marks[idx],
    typewriter = self.typewriters[idx],
  }
end

function Transcript:set_mark(idx, mark)
  self.marks[idx] = mark
  return self:get_message(idx)
end

-- stylua: ignore start
function Transcript:id() return self._transcript.chatID end
function Transcript:is_message_in_progress() return self._transcript.isMessageInProgress end
function Transcript:last_message() return self.messages[#self.messages] end
-- stylua: ignore stop

--- Get context files
---@return cody.ContextFile[]
function Transcript:context_files()
  local context = {}
  for _, message in ipairs(self._transcript.messages) do
    local files = message.contextFiles or {}
    for _, file in ipairs(files) do
      table.insert(context, file)
    end
  end

  return context
end

return Transcript

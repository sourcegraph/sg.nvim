local log = require "sg.log"

local M = {}

local handlers = {}

--- Handle Transcript Messages
---@param notification { id: string, message: cody.ExtensionTranscriptMessage  }
handlers["transcript"] = function(notification)
  local id = notification.id
  local message = notification.message
  require("sg.cody.rpc.chat").update_transcript(id, message)
end

--- Handle Chat Models
---@param notification { id: string, message: cody.ChatModelProvider[]  }
handlers["chatModels"] = function(notification)
  require("sg.cody.rpc.chat").set_models(notification.id, notification.message)
end

handlers["config"] = function(notification)
  require("sg.cody.rpc.chat").config(notification.id, notification.message)
end

M.handle_post_message = function(notification)
  if not notification or not notification.message then
    return
  end

  local handler = handlers[notification.message.type]
  if handler then
    return handler(notification)
  end

  log.info("unhandled message", notification)
end

return M

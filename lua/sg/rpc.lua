local log = require "sg.log"
local req = require("sg.request").async_request

local M = {}

--- Complete a single string snippet
--- NOTE: Must be called from async context
---@param snippet string
---@return string
function M.complete(snippet)
  log.info "sending request"
  local data = req("Complete", { message = snippet })
  log.info "got request"
  return data.completion
end

return M

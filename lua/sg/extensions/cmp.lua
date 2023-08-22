local cmp = require "cmp"

local commands = require "sg.cody.commands"

local M = {}

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "@", ".", "(", "{" }
end

source.get_keyword_pattern = function()
  -- Add dot to existing keyword characters (\k).
  return [[\%(\k\|\.\)\+]]
end

source.complete = function(self, request, callback)
  -- local prefix = string.sub(request.context.cursor_before_line, 2, request.offset - 1)
  commands.autocomplete(request, callback)
end

cmp.register_source("sg", source.new())

return M

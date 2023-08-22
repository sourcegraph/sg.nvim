local types = require "sg.types"
local layouts = types.layout_strategy

local M = {}

--- Get the correct Layout for the kind
---@param kind CodyLayoutStrategyKind
M.get = function(kind)
  if not types.layout_strategy[kind] then
    error(string.format("[cody] Not a valid layout strategy: %s", kind))
  end

  if kind == layouts.split then
    return require "sg.components.layout.split"
  elseif kind == layouts.float then
    return require "sg.components.layout.float"
  elseif kind == layouts.hover then
    return require "sg.components.layout.hover"
  else
    error(string.format("[cody] Layout strategy '%s' is not implemented", kind))
  end
end

--- Create a new layout of type kind
---@param kind CodyLayoutStrategyKind
---@param opts table
M.init = function(kind, opts)
  M.get(kind).init(opts)
end

return M

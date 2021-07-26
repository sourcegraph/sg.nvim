local bufread = require "sg.bufread"
local URI = require "sg.uri"

local transform = {}

transform.node_to_location = function(node)
  return {
    uri = URI:new(node.url):bufname(),
    range = vim.deepcopy(node.range),
  }
end

return transform

local lib = require "libsg_nvim"

local transform = {}

transform.node_to_location = function(node)
  return {
    uri = lib.get_remote_file(node.url):sourcegraph_url(),
    range = vim.deepcopy(node.range),
  }
end

return transform

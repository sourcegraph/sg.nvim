local rpc = require "sg.rpc"

-- TODO: Should find the git root instead of just the current dir to save a bunch of requests
-- local repository_ids = {}

local context = {}

--- Get the remote origin for a buffer
---@param bufnr number
---@param callback fun(string)
context.get_origin = function(bufnr, callback)
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
  rpc.get_remote_url(path, callback)
end

return context

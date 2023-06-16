local req = require("sg.request").async_request

local M = {}

--- Complete a single string snippet
--- NOTE: Must be called from async context
---@param snippet string
---@return string
function M.complete(snippet)
  local data = req("Complete", { message = snippet })
  return data.completion
end

--- Get the repository ID for a repo with a name
---@param name string
---@return string
function M.repository(name)
  local data = req("Repository", { name = name })
  return data.repository
end

function M.embeddings(repo, query)
  local data = req("Embedding", { repo = repo, query = query, code = 5, text = 0 })
  return data.embeddings
end

return M

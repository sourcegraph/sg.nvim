local req = require("sg.request").request

local M = {}

-- used only for testing purposes. helpful for unit tests
-- to ensure that we're actually still sending and responding
-- to messages
function M.echo(message, delay)
  return req("Echo", { message = message, delay = delay })
end

--- Complete a single string snippet
--- NOTE: Must be called from async context
---@param snippet string
---@return string?: The error
---@return string?: The completion
function M.complete(snippet)
  local err, data = req("Complete", { message = snippet })

  if not err then
    return nil, data.completion
  else
    return err, nil
  end
end

--- Get the repository ID for a repo with a name
---@param name string
---@return string?: The error, if any
---@return string?: The repository ID, if found
function M.repository(name)
  local err, data = req("Repository", { name = name })
  if not err then
    return nil, data.repository
  else
    return err, nil
  end
end

function M.embeddings(repo, query)
  local err, repo_id = M.repository(repo)
  if err then
    return err, nil
  end

  local err, data = req("Embedding", { repo = repo_id, query = query, code = 5, text = 0 })
  if not err then
    return nil, data.embeddings
  else
    return err, nil
  end
end

return M

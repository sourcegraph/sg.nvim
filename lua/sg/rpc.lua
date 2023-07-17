---@tag sg.rpc
---@config { ["module"] = "sg.rpc" }

local req = require("sg.request").request

local rpc = {}

-- used only for testing purposes. helpful for unit tests
-- to ensure that we're actually still sending and responding
-- to messages
function rpc.echo(message, delay)
  return req("Echo", { message = message, delay = delay })
end

--- Complete a single string snippet
--- NOTE: Must be called from async context
---@param snippet string
---@return string?: The error
---@return string?: The completion
function rpc.complete(snippet)
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
function rpc.repository(name)
  local err, data = req("Repository", { name = name })
  if not err then
    return nil, data.repository
  else
    return err, nil
  end
end

--- Get embeddings for the a repo & associated query.
---@param repo string: Repo name (github.com/neovim/neovim)
---@param query any: query string (the question you want to ask)
---@param opts table: `code`: number of code results, `text`: number of text results
---@return string?: err, if any
---@return table?: list of embeddings
function rpc.embeddings(repo, query, opts)
  opts = opts or {}
  opts.code = opts.code or 5
  opts.text = opts.text or 0

  local err, repo_id = rpc.repository(repo)
  if err then
    return err, nil
  end

  local embedding_err, data = req("Embedding", {
    repo = repo_id,
    query = query,
    code = opts.code,
    text = opts.text,
  })
  if not embedding_err then
    return nil, data.embeddings
  else
    return embedding_err, nil
  end
end

return rpc

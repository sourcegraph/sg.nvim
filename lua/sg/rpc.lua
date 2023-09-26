---@tag sg.rpc
---@config { ["module"] = "sg.rpc" }

if not require "sg.request" then
  return {}
end

local req = require("sg.request").request

local rpc = {}

-- used only for testing purposes. helpful for unit tests
-- to ensure that we're actually still sending and responding
-- to messages
function rpc.echo(message, delay, callback)
  req("Echo", { message = message, delay = delay }, callback)
end

--- Complete a single string snippet
---
---@param snippet string: Code to send as the prompt
---@param opts { prefix: string? }
---@return string?: The error
---@return string?: The completion
function rpc.complete(snippet, opts, callback)
  opts = opts or {}

  local err, data = req("Complete", { message = snippet, prefix = opts.prefix })

  if not err then
    callback(nil, data.completion)
  else
    callback(err, nil)
  end
end

--- Get the repository ID for a repo with a name
---@param name string
---@return string?: The error, if any
---@return string?: The repository ID, if found
function rpc.repository(name, callback)
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

--- Get an SgEntry based on a path
---@param path string
---@param callback fun(err: string?, entry: SgEntry?)
function rpc.get_entry(path, callback)
  req("sourcegraph/get_entry", { path = path }, callback)
end

--- Get file contents for a sourcegraph file
---@param remote string
---@param oid string
---@param path string
---@return string?: err, if any
---@return string[]?: contents, if successful
function rpc.get_file_contents(remote, oid, path)
  return req("sourcegraph/get_file_contents", { remote = remote, oid = oid, path = path })
end

--- Get directory contents for a sourcegraph directory
---@param remote string
---@param oid string
---@param path string
---@return string?: err, if any
---@return SgEntry[]?: contents, if successful
function rpc.get_directory_contents(remote, oid, path, callback)
  return req("sourcegraph/get_directory_contents", { remote = remote, oid = oid, path = path }, callback)
end

--- Get search results
---@param query string
---@return string?: err, if any
---@return SgSearchResult[]?: contents, if successful
function rpc.get_search(query)
  return req("sourcegraph/search", { query = query })
end

--- Get info about current sourcegraph info
function rpc.get_info(callback)
  return req("sourcegraph/info", { query = "LUL" }, callback)
end

--- Get info about current sourcegraph info
function rpc.get_link(path, line, col, callback)
  req("sourcegraph/link", { path = path, line = line, col = col }, callback)
end

function rpc.get_remote_url(path, callback)
  req("sourcegraph/get_remote_url", { path = path }, callback)
end

return rpc

---@tag sg.rpc
---@config { ["module"] = "sg.rpc" }

local req = require("sg.request").request

local rpc = {}

-- used only for testing purposes. helpful for unit tests
-- to ensure that we're actually still sending and responding
-- to messages
function rpc.echo(message, delay, callback)
  req("Echo", { message = message, delay = delay }, callback)
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
---@param callback fun(err: string?, contents: string[]?): nil
function rpc.get_file_contents(remote, oid, path, callback)
  req("sourcegraph/get_file_contents", { remote = remote, oid = oid, path = path }, callback)
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
---@param callback function(err: string?, res: SgSearchResult[]?)
function rpc.get_search(query, callback)
  req("sourcegraph/search", { query = query }, callback)
end

--- Get info about current sourcegraph info
function rpc.get_info(callback)
  return req("sourcegraph/info", { query = "LUL" }, callback)
end

--- Get info about current sourcegraph info
---@param path string
---@param position { start_line: number, start_col: number, end_line: number, end_col: number }
---@param callback any
function rpc.get_link(path, position, callback)
  ---@type table
  local args = vim.deepcopy(position)
  args.path = path

  req("sourcegraph/link", args, callback)
end

function rpc.get_remote_url(path, callback)
  req("sourcegraph/get_remote_url", { path = path }, callback)
end

function rpc.get_auth(creds, callback)
  req("sourcegraph/auth", creds or {}, callback)
end

function rpc.get_user_info(callback)
  req("sourcegraph/get_user_info", { testing = false }, callback)
end

function rpc.dotcom_login(port, callback)
  req("sourcegraph/dotcom_login", { port = port }, callback)
end

return rpc

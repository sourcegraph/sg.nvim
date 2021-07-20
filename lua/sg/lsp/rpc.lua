local vim = vim
local log = require "sg.log"
local protocol = require "vim.lsp.protocol"
local validate = vim.validate

-- TODO replace with a better implementation.

local M = {}

--@private
--- Encodes to JSON.
---
--@param data (table) Data to encode
--@returns (string) Encoded object
local function json_encode(data)
  local status, result = pcall(vim.fn.json_encode, data)
  if status then
    return true, result
  else
    return nil, result
  end
end
--@private
--- Decodes from JSON.
---
--@param data (string) Data to decode
--@returns (table) Decoded JSON object
local function json_decode(data)
  local status, result = pcall(vim.fn.json_decode, data)
  if status then
    return true, result
  else
    return nil, result
  end
end

local function format_message_with_content_length(encoded_message)
  local message = table.concat {
    "Content-Length: ",
    tostring(#encoded_message),
    "\r\n\r\n",
    encoded_message,
  }

  log.trace(message)
  return message
end

function M.read_message()
  local line = io.read "*l"
  local length = line:lower():match "content%-length:%s*(%d+)"
  return json_decode(io.read(2 + length):sub(2))
end

function M.send_message(payload, pipe)
  if not pipe then
    pipe = io.stdout
  end

  log.debug("rpc.send.payload", payload)
  local ok, encoded = json_encode(payload)
  if ok then
    pipe:write(format_message_with_content_length(encoded))
  else
    error("Could not encode:" .. payload)
  end
end

function M.respond(id, err, result)
  assert(type(id) == "number", "id must be a number")
  M.send_message { jsonrpc = "2.0", id = id, error = err, result = result }
end

function M.notify(method, params)
  assert(type(method) == "string", "method must be a string")
  M.send_message { jsonrpc = "2.0", method = method, params = params or {} }
end

--@private
--- Parses an LSP Message's header
---
--@param header: The header to parse.
--@returns Parsed headers
local function parse_headers(header)
  if type(header) ~= "string" then
    return nil
  end
  local headers = {}
  for line in vim.gsplit(header, "\r\n", true) do
    if line == "" then
      break
    end
    local key, value = line:match "^%s*(%S+)%s*:%s*(.+)%s*$"
    if key then
      key = key:lower():gsub("%-", "_")
      headers[key] = value
    else
      local _ = log.error() and log.error("invalid header line %q", line)
      error(string.format("invalid header line %q", line))
    end
  end
  headers.content_length = tonumber(headers.content_length)
    or error(string.format("Content-Length not found in headers. %q", header))
  return headers
end

-- This is the start of any possible header patterns. The gsub converts it to a
-- case insensitive pattern.
local header_start_pattern = ("content"):gsub("%w", function(c)
  return "[" .. c .. c:upper() .. "]"
end)

--@private
--- The actual workhorse.
local function request_parser_loop()
  local buffer = ""
  while true do
    -- A message can only be complete if it has a double CRLF and also the full
    -- payload, so first let's check for the CRLFs
    local start, finish = buffer:find("\r\n\r\n", 1, true)
    -- Start parsing the headers
    if start then
      -- This is a workaround for servers sending initial garbage before
      -- sending headers, such as if a bash script sends stdout. It assumes
      -- that we know all of the headers ahead of time. At this moment, the
      -- only valid headers start with "Content-*", so that's the thing we will
      -- be searching for.
      -- TODO(ashkan) I'd like to remove this, but it seems permanent :(
      local buffer_start = buffer:find(header_start_pattern)
      local headers = parse_headers(buffer:sub(buffer_start, start - 1))
      buffer = buffer:sub(finish + 1)
      local content_length = headers.content_length
      -- Keep waiting for data until we have enough.
      while #buffer < content_length do
        buffer = buffer .. (coroutine.yield() or error "Expected more data for the body. The server may have died.") -- TODO hmm.
      end
      local body = buffer:sub(1, content_length)
      buffer = buffer:sub(content_length + 1)
      -- Yield our data.
      buffer = buffer
        .. (coroutine.yield(headers, body) or error "Expected more data for the body. The server may have died.") -- TODO hmm.
    else
      -- Get more data since we don't have enough.
      buffer = buffer .. (coroutine.yield() or error "Expected more data for the header. The server may have died.") -- TODO hmm.
    end
  end
end

local client_errors = vim.tbl_add_reverse_lookup {
  INVALID_SERVER_MESSAGE = 1,
  INVALID_SERVER_JSON = 2,
  NO_RESULT_CALLBACK_FOUND = 3,
  READ_ERROR = 4,
  NOTIFICATION_HANDLER_ERROR = 5,
  SERVER_REQUEST_HANDLER_ERROR = 6,
  SERVER_RESULT_CALLBACK_ERROR = 7,
}

--- Constructs an error message from an LSP error object.
---
--@param err (table) The error object
--@returns (string) The formatted error message
local function format_rpc_error(err)
  validate {
    err = { err, "t" },
  }

  -- There is ErrorCodes in the LSP specification,
  -- but in ResponseError.code it is not used and the actual type is number.
  local code
  if protocol.ErrorCodes[err.code] then
    code = string.format("code_name = %s,", protocol.ErrorCodes[err.code])
  else
    code = string.format("code_name = unknown, code = %s,", err.code)
  end

  local message_parts = { "RPC[Error]", code }
  if err.message then
    table.insert(message_parts, "message =")
    table.insert(message_parts, string.format("%q", err.message))
  end
  if err.data then
    table.insert(message_parts, "data =")
    table.insert(message_parts, vim.inspect(err.data))
  end
  return table.concat(message_parts, " ")
end

--- Creates an RPC response object/table.
---
--@param code RPC error code defined in `vim.lsp.protocol.ErrorCodes`
--@param message (optional) arbitrary message to send to server
--@param data (optional) arbitrary data to send to server
local function rpc_response_error(code, message, data)
  -- TODO should this error or just pick a sane error (like InternalError)?
  local code_name = assert(protocol.ErrorCodes[code], "Invalid RPC error code")
  return setmetatable({
    code = code,
    message = message or code_name,
    data = data,
  }, {
    __tostring = format_rpc_error,
  })
end

local default_handlers = {}
--@private
--- Default handler for notifications sent to an LSP server.
---
--@param method (string) The invoked LSP method
--@param params (table): Parameters for the invoked LSP method
function default_handlers.notification(method, params)
  local _ = log.debug() and log.debug("notification", method, params)
end
--@private
--- Default handler for requests sent to an LSP server.
---
--@param method (string) The invoked LSP method
--@param params (table): Parameters for the invoked LSP method
--@returns `nil` and `vim.lsp.protocol.ErrorCodes.MethodNotFound`.
function default_handlers.server_request(method, params)
  local _ = log.debug() and log.debug("server_request", method, params)
  return nil, rpc_response_error(protocol.ErrorCodes.MethodNotFound)
end
--@private
--- Default handler for when a client exits.
---
--@param code (number): Exit code
--@param signal (number): Number describing the signal used to terminate (if
---any)
function default_handlers.on_exit(code, signal)
  local _ = log.info() and log.info("client_exit", { code = code, signal = signal })
end
--@private
--- Default handler for client errors.
---
--@param code (number): Error code
--@param err (any): Details about the error
---any)
function default_handlers.on_error(code, err)
  local _ = log.error() and log.error("client_error:", client_errors[code], err)
end

--- Starts an LSP server process and create an LSP RPC client object to
--- interact with it.
---
--@param cmd (string) Command to start the LSP server.
--@param cmd_args (table) List of additional string arguments to pass to {cmd}.
--@param handlers (table, optional) Handlers for LSP message types. Valid
---handler names are:
--- - `"notification"`
--- - `"server_request"`
--- - `"on_error"`
--- - `"on_exit"`
--@param extra_spawn_params (table, optional) Additional context for the LSP
--- server process. May contain:
--- - {cwd} (string) Working directory for the LSP server process
--- - {env} (table) Additional environment variables for LSP server process
--@returns Client RPC object.
---
--@returns Methods:
--- - `notify()` |vim.lsp.rpc.notify()|
--- - `request()` |vim.lsp.rpc.request()|
---
--@returns Members:
--- - {pid} (number) The LSP server's PID.
--- - {handle} A handle for low-level interaction with the LSP server process
---   |vim.loop|.
local function start(cmd, cmd_args, handlers, extra_spawn_params)
  --@private
  local function on_error(errkind, ...)
    assert(client_errors[errkind])
    -- TODO what to do if this fails?
    pcall(handlers.on_error, errkind, ...)
  end

  --@private
  local function pcall_handler(errkind, status, head, ...)
    if not status then
      on_error(errkind, head, ...)
      return status, head
    end
    return status, head, ...
  end
  --@private
  local function try_call(errkind, fn, ...)
    return pcall_handler(errkind, pcall(fn, ...))
  end

  -- TODO periodically check message_callbacks for old requests past a certain
  -- time and log them. This would require storing the timestamp. I could call
  -- them with an error then, perhaps.

  local request_parser = coroutine.wrap(request_parser_loop)
  request_parser()
  stdout:read_start(function(err, chunk)
    if err then
      -- TODO better handling. Can these be intermittent errors?
      on_error(client_errors.READ_ERROR, err)
      return
    end
    -- This should signal that we are done reading from the client.
    if not chunk then
      return
    end
    -- Flush anything in the parser by looping until we don't get a result
    -- anymore.
    while true do
      local headers, body = request_parser(chunk)
      -- If we successfully parsed, then handle the response.
      if headers then
        handle_body(body)
        -- Set chunk to empty so that we can call request_parser to get
        -- anything existing in the parser to flush.
        chunk = ""
      else
        break
      end
    end
  end)
end

return M
-- vim:sw=2 ts=2 et

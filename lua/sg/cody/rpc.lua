local protocol = require "sg.cody.protocol"
local log = require "sg.log"
local config = require "sg.config"
local auth = require "sg.auth"
local vendored_rpc = require "sg.vendored.vim-lsp-rpc"
local utils = require "sg.utils"

local M = {}

--- Whether the current cody connection is ready for requests
---     TODO: We should think more about how to use this and structure it.
---@return boolean
local is_ready = function(opts)
  -- TODO(auth-test): Not a huge fan of this :)
  if config.testing then
    return true
  end

  opts = opts or {}
  if opts.method == "initialize" then
    return true
  end

  if not auth.get() then
    return false
  end

  ---@diagnostic disable-next-line: return-type-mismatch
  return M.server_info.authenticated and M.server_info.codyEnabled
end

local track = function(msg)
  log.trace(msg)

  if config.testing then
    table.insert(M.messages, msg)
  end
end

local cody_args = { config.cody_agent }
-- We can insert node breakpoint to debug the agent if needed
-- table.insert(cody_args, 1, "--insert-brk")

---@type table<string, CodyMessageHandler?>
M.message_callbacks = {}

--- Start the server
---@param opts { force: boolean? }?
---@param callback fun(client: VendoredPublicClient?)
---@return nil
M.start = function(opts, callback)
  assert(callback, "Must pass a callback")

  if not config.enable_cody then
    return callback()
  end

  opts = opts or {}

  if M.client and not opts.force then
    return callback(M.client)
  end

  if M.client then
    M.shutdown()
    M.exit()
    vim.wait(10)

    M.client = nil
  end

  local ok, reason = require("sg.utils").valid_node_executable(config.node_executable)
  if not ok then
    require("sg.notify").INVALID_NODE(reason)
    return callback()
  end

  ---@type {["chat/updateMessageInProgress"]: fun(noti: CodyChatUpdateMessageInProgressNoti?)}
  local notification_handlers = {
    ["debug/message"] = function(noti)
      log.debug("[cody-agent] debug:", noti.message)
    end,

    ["chat/updateMessageInProgress"] = function(noti)
      if not noti or not noti.data or not noti.data.id then
        return
      end

      if not noti.text then
        M.message_callbacks[noti.data.id] = nil
        return
      end

      local notification_callback = M.message_callbacks[noti.data.id]
      if notification_callback and noti.text then
        noti.text = vim.trim(noti.text) -- trim random white space
        notification_callback(noti)
      end
    end,
  }

  local server_handlers = {
    ["showQuickPick"] = function(_, params)
      return function(respond)
        vim.ui.select(params, nil, function(selected)
          respond(selected)
        end)
      end
    end,
  }

  -- Clear old information before restarting the client
  M.messages = {}
  M.server_info = {}

  M.client = vendored_rpc.start(config.node_executable, cody_args, {
    notification = function(method, data)
      if notification_handlers[method] then
        notification_handlers[method](data)
      else
        log.warn("[cody-agent] unhandled method:", method)
      end
    end,
    server_request = function(method, params)
      track {
        type = "server_request",
        method = method,
        params = params,
      }

      local handler = server_handlers[method]
      if handler then
        return handler(method, params)
      else
        log.warn("[cody-agent] unhandled server request:", method)
      end
    end,
    on_exit = function(code, signal)
      if code ~= 0 then
        log.warn("[cody-agent] closed cody agent", code, signal)
      end
    end,
  })

  -- Run initialize as first message to send
  M.initialize(function(err, data)
    if err ~= nil then
      vim.notify("[sg-cody]" .. vim.inspect(err))
      return nil
    end

    if not data then
      vim.notify "[sg-cody] expected initialize data, but got none"
      return nil
    end

    -- When not testing, we don't need to check auth
    -- (this won't work with actual sourcegraph isntance, so it's
    --  not actually skipping auth on the backend or anything)
    if not config.testing then
      if not data.authenticated then
        require("sg.notify").INVALID_AUTH()
        return nil
      end

      if not data.codyEnabled then
        require("sg.notify").CODY_DISABLED()
        return nil
      end
    end

    -- Clear or reset the server information
    M.server_info = data or {}

    -- And then respond that we've initialized
    local _ = M.notify("initialized", {})

    -- Load all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      protocol.did_open(bufnr)
    end

    -- Notify current buffer
    protocol.did_focus(vim.api.nvim_get_current_buf())

    callback(M.client)
  end)
end

--- Send a notification message to the client.
---
---@param method string: The notification method name.
---@param params table: The parameters to send with the notification.
M.notify = function(method, params)
  -- TODO: I'm wondering if this should be in start?...
  --        It feels a bit less likely to cause weird race condition
  --        problems in the notify and requests compared to in start?
  --
  --        We can revisit this later though.
  if not auth.get() then
    return
  end

  M.start({}, function(client)
    if not client then
      return
    end

    track {
      type = "notify",
      method = method,
      params = params,
    }

    client.notify(method, params)
  end)
end

--- Send a request to cody
---@param method string
---@param params any
---@param callback fun(E, R)
M.request = function(method, params, callback)
  if not auth.get() then
    return callback("Invalid auth. Cannot complete cody requeest", nil)
  end

  M.start({}, function(client)
    if not client then
      return callback("RPC client not initialized", nil)
    end

    track {
      type = "request",
      method = method,
      params = params,
    }

    if not is_ready { method = method } then
      callback(
        "Unable to get token and/or endpoint for sourcegraph."
          .. " Use `:SourcegraphLogin` or `:help sg` for more information",
        nil
      )
      return
    end

    return client.request(method, params, function(err, result)
      track {
        type = "response",
        method = method,
        result = result or "none",
        err = err,
      }

      return callback(err, result)
    end)
  end)
end

--- Initialize the client by sending initialization info to the server.
--- This must be called before any other requests.
---@return string?
---@return CodyServerInfo?
M.initialize = function(callback)
  local creds = auth.get()
  if not creds then
    require("sg.notify").NO_AUTH()

    creds = {
      ---@diagnostic disable-next-line: assign-type-mismatch
      endpoint = nil,
      ---@diagnostic disable-next-line: assign-type-mismatch
      token = nil,
    }
  end

  require("sg.cody.context").get_origin(0, function(remote_url)
    ---@type CodyClientInfo
    local info = {
      name = "neovim",
      version = require("sg.private.data").version,
      workspaceRootUri = vim.uri_from_fname(vim.loop.cwd() or ""),
      extensionConfiguration = {
        accessToken = creds.token,
        serverEndpoint = creds.endpoint,
        codebase = remote_url,
        customHeaders = { ["User-Agent"] = "Sourcegraph Cody Neovim Plugin" },
        eventProperties = {
          anonymousUserID = require("sg.private.data").get_cody_data().user,
          prefix = "CodyNeovimPlugin",
          client = "NEOVIM_CODY_EXTENSION",
          source = "IDEEXTENSION",
        },
      },
      capabilities = {
        chat = "streaming",
      },
    }

    M.request("initialize", info, callback)
  end)
end

--- Shuts down the client by sending a shutdown request and waiting for completion.
M.shutdown = function()
  if not M.client then
    return
  end

  local done = false
  M.client.request("shutdown", {}, function()
    track { type = "shutdown" }
    done = true
  end)

  vim.wait(100, function()
    return done
  end)
end

M.exit = function()
  if not M.client then
    return
  end

  M.notify("exit", {})

  -- Force closing the connection.
  -- I think this is good to make sure we don't leave anything running
  M.client.terminate()
end

---@type CodyServerInfo
M.server_info = {
  name = "",
  authenticated = false,
  codyEnabled = false,
}

_SG_CODY_RPC_MESSAGES = _SG_CODY_RPC_MESSAGES or {}
M.messages = _SG_CODY_RPC_MESSAGES

M.execute = {}

--- List currently available messages
M.execute.list_recipes = function(callback)
  M.request("recipes/list", {}, callback)
end

--- Execute a chat question and get a streaming response
---@param message string
---@param callback CodyMessageHandler
---@return table | nil
---@return table | nil
M.execute.chat_question = function(message, callback)
  local message_id = utils.uuid()
  M.message_callbacks[message_id] = callback

  return M.request(
    "recipes/execute",
    { id = "chat-question", humanChatInput = message, data = { id = message_id } },
    callback
  )
end

--- Execute a code question and get a streaming response
--- Returns only code (hopefully)
---@param message string
---@param callback CodyMessageHandler
---@return table | nil
---@return table | nil
M.execute.code_question = function(message, callback)
  local message_id = utils.uuid()
  M.message_callbacks[message_id] = callback

  return M.request(
    "recipes/execute",
    { id = "code-question", humanChatInput = message, data = { id = message_id } },
    callback
  )
end

M.execute.autocomplete = function(file, line, character, callback)
  return M.request(
    "autocomplete/execute",
    { filePath = file, position = { line = line, character = character } },
    callback
  )
end

M.transcript = {}

M.transcript.reset = function()
  return M.notify("transcript/reset", {})
end

return M

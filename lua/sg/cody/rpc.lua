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

--- Gets the server config
---@return CodyClientInfo
local get_server_config = function(creds, remote_url)
  -- Add any custom headers from user configuration
  local custom_headers = { ["User-Agent"] = "Sourcegraph Cody Neovim Plugin" }
  if config.src_headers then
    custom_headers = vim.tbl_extend("error", custom_headers, config.src_headers)
  end

  return {
    name = "neovim",
    version = require("sg.private.data").version,
    workspaceRootUri = vim.uri_from_fname(vim.loop.cwd() or ""),
    extensionConfiguration = {
      accessToken = creds.token,
      serverEndpoint = creds.endpoint,
      codebase = remote_url,
      customHeaders = custom_headers,
      eventProperties = {
        anonymousUserID = require("sg.private.data").get_cody_data().user,
        prefix = "CodyNeovimPlugin",
        client = "NEOVIM_CODY_EXTENSION",
        source = "IDEEXTENSION",
      },
      customConfiguration = {
        -- ["cody.useContext"] = "keyword",
        ["cody.experimental.symfContext"] = true,
        -- ["cody.debug.enable"] = true,
        -- ["cody.debug.verbose"] = true,
      },
      -- TODO: Which should I put here? I cannot get multi-line completions anymore
      autocompleteAdvancedProvider = "fireworks",
      autocompleteAdvancedModel = "starcoder-7b",
    },
    capabilities = {
      chat = "streaming",
    },
  }
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

  if not config.skip_node_check then
    local ok, reason = require("sg.utils").valid_node_executable(config.node_executable)
    if not ok then
      require("sg.notify").INVALID_NODE(reason)
      return callback()
    end
  end

  ---@type {["chat/updateMessageInProgress"]: fun(noti: CodyChatUpdateMessageInProgressNoti?)}
  local notification_handlers = {
    ["webview/postMessage"] = function(notification)
      return require("sg.cody.rpc.webview").handle_post_message(notification)
    end,

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
    ["webview/create"] = function(_, params)
      vim.notify(string.format("WEBVIEW CREATE: %s", vim.inspect(params)))
    end,

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
---@param callback? fun(E, R)
M.request = function(method, params, callback)
  callback = callback or function() end

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
          .. " Use `:SourcegraphLogin` or `:help sg` for more information\n"
          .. vim.inspect(M.server_info),
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
    local info = get_server_config(creds, remote_url)
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

M.config_did_change = function()
  M.initialize(function(err, data)
    if err then
      require("sg.log").error(err)
    end

    -- Clear or reset the server information
    M.server_info = data or {}
  end)
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

--- Execute a chat question and get a streaming response
---@param message string
---@param callback CodyMessageHandler
---@return table | nil
---@return table | nil
M.execute.chat_question = function(message, callback)
  error "DO NOT USE CHAT QUESTION"

  local message_id = utils.uuid()
  M.message_callbacks[message_id] = callback

  return M.request(
    "recipes/execute",
    { id = "chat-question", humanChatInput = message, data = { id = message_id } },
    function(err, _)
      local ratelimit = require "sg.ratelimit"
      if ratelimit.is_ratelimit_err(err) then
        -- Notify user of error message
        callback {
          speaker = "cody",
          text = err.message,
          data = { id = message_id },
        }

        -- Mark callback as "completed"
        ---@diagnostic disable-next-line: param-type-mismatch
        callback(nil)

        -- Set notification
        return ratelimit.notify_ratelimit "chat"
      end
    end
  )
end

--- Execute a code question and get a streaming response
--- Returns only code (hopefully)
---@param message string
---@return table | nil
---@return table | nil
M.execute.code_question = function(message)
  error "code_question"

  local message_id = utils.uuid()
  -- M.message_callbacks[message_id] = callback

  return M.request(
    "recipes/execute",
    { id = "code-question", humanChatInput = message, data = { id = message_id } },
    function(err, _)
      local ratelimit = require "sg.ratelimit"
      if ratelimit.is_ratelimit_err(err) then
        -- Notify user of error message
        -- callback {
        --   speaker = "cody",
        --   text = err.message,
        --   data = { id = message_id },
        -- }

        -- Mark callback as "completed"
        ---@diagnostic disable-next-line: param-type-mismatch
        -- callback(nil)

        -- Set notification
        return ratelimit.notify_ratelimit "chat"
      end
    end
  )
end

M.execute.autocomplete = function(file, line, character, callback)
  return M.request(
    "autocomplete/execute",
    { filePath = file, position = { line = line, character = character } },
    callback
  )
end

-- // The completion was presented to the user
-- 'autocomplete/completionSuggested': [CompletionItemParams]
--
-- export interface CompletionItemParams {
--     completionID: CompletionItemID
-- }
M.execute.autocomplete_suggested = function(id)
  return M.notify("autocomplete/completionSuggested", { completionID = id })
end

-- // The completion was accepted by the user
-- 'autocomplete/completionAccepted': [CompletionItemParams]
M.execute.autocomplete_accepted = function(id)
  return M.notify("autocomplete/completionAccepted", { completionID = id })
end

M.transcript = {}

M.transcript.reset = function()
  return M.notify("transcript/reset", {})
end

M.command = {}

M.command.explain = function(callback)
  return M.request("commands/explain", {}, require("sg.cody.rpc.chat").make_chat({}, callback))
end

M.graphql_currentUserIsPro = function(callback)
  return M.request("graphql/currentUserIsPro", {}, callback)
end

return M

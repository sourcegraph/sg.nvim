-- Attempt to clear SG_CODY_CLIENT if one is already
-- running currently.
--
-- This should hopefully prevent multiple cody clients from
-- running at a time.
if SG_CODY_CLIENT then
  local ok, err = pcall(SG_CODY_CLIENT.terminate)
  if not ok then
    vim.notify(string.format("[cody-agent] Attempting to close existing client failed:%s", err))
  end

  SG_CODY_CLIENT = nil
end

local async = require "plenary.async"
local void = async.void

local log = require "sg.log"
local config = require "sg.config"
local auth = require "sg.auth"
local vendored_rpc = require "sg.vendored.vim-lsp-rpc"
local utils = require "sg.utils"

local M = {}

---@type CodyServerInfo
M.server_info = {}

--- Whether the current cody connection is ready for requests
---     TODO: We should think more about how to use this and structure it.
---@return boolean
local is_ready = function(opts)
  -- TODO(auth-test): Not a huge fan of this :)
  if config.testing then
    return true
  end

  opts = opts or {}
  if not auth.valid() then
    return false
  end

  if opts.method == "initialize" then
    return true
  end

  return M.server_info.authenticated and M.server_info.codyEnabled
end

_SG_CODY_RPC_MESSAGES = _SG_CODY_RPC_MESSAGES or {}
M.messages = _SG_CODY_RPC_MESSAGES

local track = function(msg)
  if config.testing then
    table.insert(M.messages, msg)
  end
end

M.message_callbacks = {}

local notification_handlers = {
  ["chat/updateMessageInProgress"] = function(noti)
    if not noti or not noti.text then
      if noti.data and M.message_callbacks[noti.data] ~= nil then
        M.message_callbacks[noti.data.id] = nil
      end
      return
    end

    if noti.data and M.message_callbacks[noti.data.id] ~= nil then
      M.message_callbacks[noti.data.id](noti)
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

local cody_args = { config.cody_agent }

-- We can insert node breakpoint to debug the agent if needed
if false then
  table.insert(cody_args, 1, "--insert-brk")
end

SG_CODY_CLIENT = vendored_rpc.start(config.node_executable, cody_args, {
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
    log.warn("[cody-agen] closed cody agent", code, signal)
  end,
})

local client = SG_CODY_CLIENT
if not client then
  vim.notify "[sg.nvim] failed to start cody-agent"
  return nil
end

--- Send a notification message to the client.
---
---@param method string: The notification method name.
---@param params table: The parameters to send with the notification.
M.notify = function(method, params)
  track {
    type = "notify",
    method = method,
    params = params,
  }

  log.trace("notify", method, params)
  client.notify(method, params)
end

M.request = async.wrap(function(method, params, callback)
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

  log.trace("request", method, params)
  return client.request(method, params, function(err, result)
    track {
      type = "response",
      method = method,
      result = result or "none",
      err = err,
    }

    return callback(err, result)
  end)
end, 3)

--- Initialize the client by sending initialization info to the server.
--- This must be called before any other requests.
---@return string?
---@return CodyServerInfo?
M.initialize = function()
  local creds = auth.get()
  if not creds then
    require("sg.notify").NO_AUTH()
    creds = {}
  end

  ---@type CodyClientInfo
  local info = {
    name = "neovim",
    version = "0.1",
    workspaceRootPath = vim.loop.cwd() or "",
    connectionConfiguration = {
      accessToken = creds.token,
      serverEndpoint = creds.endpoint,
      -- TODO: Custom Headers for neovim
      -- customHeaders = { "
    },
    capabilities = {
      chat = "streaming",
    },
  }

  return M.request("initialize", info)
end

--- Shuts down the client by sending a shutdown request and waiting for completion.
M.shutdown = function()
  local done = false
  client.request("shutdown", {}, function()
    track { type = "shutdown" }
    done = true
  end)

  vim.wait(100, function()
    return done
  end)
end

M.exit = function()
  M.notify("exit", {})

  -- Force closing the connection.
  -- I think this is good to make sure we don't leave anything running
  client.terminate()
end

M.execute = {}

--- List currently available messages
M.execute.list_recipes = function()
  local err, data = M.request("recipes/list", {})
  return err, data
end

--- Execute a chat question and get a streaming response
--- Sadly just puts whatever we get as the response into the currently
--- open window... I will fix this later (needs protocol changes)
---@param message string
---@param callback function(noti)
---@return table | nil
---@return table | nil
M.execute.chat_question = function(message, callback)
  local message_id = utils.uuid()

  M.message_callbacks[message_id] = callback

  return M.request("recipes/execute", { id = "chat-question", humanChatInput = message, data = { id = message_id } })
end

-- M.execute.fixup = function(message) end

-- M.execute.git_history = function()
--   return M.request("recipes/execute", { id = "git-history", humanChatInput = "" })
-- end

-- ===== REQUIRE RUNTIME SIDE EFFECT HERE ======
-- Always attempt to the start the server when loading.
void(function()
  -- Run initialize as first message to send
  local err, data = M.initialize()
  if err ~= nil then
    vim.notify("[sg-cody]" .. vim.inspect(err))
    return
  end

  if not data then
    vim.notify "[sg-cody] expected initialize data, but got none"
    return
  end

  -- TODO: This feels sad and painful
  if not config.testing then
    if not data.authenticated then
      require("sg.notify").INVALID_AUTH()
      return
    end

    if not data.codyEnabled then
      require("sg.notify").CODY_DISABLED()
      return
    end
  end

  M.server_info = data

  -- And then respond that we've initialized
  local _ = M.notify("initialized", {})
end)()
-- =============================================

return M

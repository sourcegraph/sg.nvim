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
local env = require "sg.env"
local vendored_rpc = require "sg.vendored.vim-lsp-rpc"

local M = {}

M.messages = {}
local track = function(msg)
  if config.testing then
    table.insert(M.messages, msg)
  end
end

M.response_buffers = {}

local notification_handlers = {
  ["chat/updateMessageInProgress"] = function(noti)
    if not noti or not noti.text then
      -- TODO: Remove the response_buffer once the message completes.
      -- This might require some protocol changes to signal when a response completed.
      return
    end

    local bufnr = M.response_buffers[noti.data]
    if bufnr ~= nil then
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(vim.trim(noti.text), "\n"))
      return
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

M.initialize = function()
  ---@type CodyClientInfo
  local info = {
    name = "neovim",
    version = "0.1",
    workspaceRootPath = vim.loop.cwd() or "",
    connectionConfiguration = {
      accessToken = env.token(),
      serverEndpoint = env.endpoint(),
      -- TODO: Custom Headers for neovim
      -- customHeaders = { "
    },
    capabilities = {
      chat = "streaming",
    },
  }

  return M.request("initialize", info)
end

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
  M.notify "exit"

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
---@param messageId string?
---@return table | nil
---@return table | nil
M.execute.chat_question = function(message, messageId)
  return M.request("recipes/execute", { id = "chat-question", humanChatInput = message, data = messageId })
end

-- M.execute.fixup = function(message) end

-- M.execute.git_history = function()
--   return M.request("recipes/execute", { id = "git-history", humanChatInput = "" })
-- end

-- ===== REQUIRE RUNTIME SIDE EFFECT HERE ======
-- Always attempt to the start the server when loading.
void(function()
  -- Run initialize as first message to send
  local _ = M.initialize()

  -- And then respond that we've initialized
  local _ = M.notify("initialized", {})
end)()
-- =============================================

return M

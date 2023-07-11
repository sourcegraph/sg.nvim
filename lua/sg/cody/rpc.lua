-- Attempt to clear SG_CODY_CLIENT if one is already
-- running currently.
--
-- This should hopefully prevent multiple cody clients from
-- running at a time.
if SG_CODY_CLIENT then
  pcall(SG_CODY_CLIENT.terminate)
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

local notification_handlers = {
  ["chat/updateMessageInProgress"] = function(noti)
    if not noti or not noti.text then
      return
    end

    local Message = require "sg.cody.message"
    local Speaker = require "sg.cody.speaker"

    local CodyLayout = require "sg.components.cody_layout"
    local active = CodyLayout.active

    if active then
      active.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
      active:render()
    else
      local layout = CodyLayout.init {}
      layout:mount()

      layout.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
      layout:render()
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

SG_CODY_CLIENT = vendored_rpc.start(config.node_executable, { config.cody_agent }, {
  notification = function(method, data)
    if notification_handlers[method] then
      notification_handlers[method](data)
    else
      log.warn("[cody-agent] unhandled method:", method)
    end
  end,
  server_request = function(method, params)
    if config.testing then
      table.insert(M.messages, {
        type = "server_request",
        method = method,
        params = params,
      })
    end

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
  if config.testing then
    table.insert(M.messages, {
      type = "notify",
      method = method,
      params = params,
    })
  end

  log.trace("notify", method, params)
  client.notify(method, params)
end

M.request = async.wrap(function(method, params, callback)
  if config.testing then
    table.insert(M.messages, {
      type = "request",
      method = method,
      params = params,
    })
  end

  log.trace("request", method, params)
  return client.request(method, params, function(err, result)
    if config.testing then
      table.insert(M.messages, {
        type = "response",
        method = method,
        result = result or "none",
        err = err,
      })
    end

    return callback(err, result)
  end)
end, 3)

M.initialize = function()
  ---@type CodyClientInfo
  local info = {
    name = "neovim",
    version = "0.1",
    workspaceRootPath = vim.loop.cwd(),
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
  return M.request "shutdown"
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
---@return table | nil
---@return table | nil
M.execute.chat_question = function(message)
  return M.request("recipes/execute", { id = "chat-question", humanChatInput = message })
end

M.execute.fixup = function(message) end

M.execute.git_history = function()
  return M.request("recipes/execute", { id = "git-history", humanChatInput = "" })
end

void(function()
  -- Run initialize as first message to send
  local _ = M.initialize()

  -- And then respond that we've initialized
  local _ = M.notify("initialized", {})
end)()

return M

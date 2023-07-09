local async = require "plenary.async"
local void = async.void

local log = require "sg.log"
local config = require "sg.config"
local env = require "sg.env"

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
      print "failed to render... no active"
    end
  end,
}

local client = vim.lsp.rpc.start(config.node_executable, { config.cody_agent }, {
  notification = function(method, data)
    if notification_handlers[method] then
      notification_handlers[method](data)
    else
      log.warn("[cody-agent] unhandled method:", method)
    end
  end,
})

if not client then
  vim.notify "[sg.nvim] failed to start cody-agent"
  return nil
end

M.notify = function(method, params)
  if config.testing then
    table.insert(M.messages, {
      type = "notify",
      method = method,
      -- params = params,
    })
  end

  client.notify(method, params)
end

M.request = async.wrap(function(method, params, callback)
  if config.testing then
    table.insert(M.messages, {
      type = "request",
      method = method,
    })
  end

  return client.request(method, params, function(err, result)
    if config.testing then
      table.insert(M.messages, {
        type = "response",
        method = method,
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
    workspaceRootPath = vim.uv.cwd(),
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

void(function()
  -- Run initialize as first message to send
  local _ = M.initialize()

  -- And then respond that we've initialized
  local _ = M.notify("initialized", {})
end)()

return M

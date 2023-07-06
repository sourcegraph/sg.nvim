local async = require "plenary.async"
local void = async.void

local log = require "sg.log"
local config = require "sg.config"

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
  error "failed!!"
end

local request = async.wrap(client.request, 3)
local notify = client.notify

local function initialize()
  ---@type CodyClientInfo
  local info = {
    name = "neovim",
    version = "0.1",
    workspaceRootPath = vim.uv.cwd(),
    connectionConfiguration = {
      accessToken = vim.env.SRC_ACCESS_TOKEN,
      serverEndpoint = vim.env.SRC_ENDPOINT,
      -- TODO: Custom Headers for neovim
      -- customHeaders = { "
    },
    capabilities = {
      chat = "streaming",
    },
  }

  return request("initialize", info)
end

-- Run initialize as first message to send
void(function()
  local _ = initialize()
  local _ = notify("initialized", {})
end)()

local execute = {}

--- List currently available messages
execute.list_recipes = function()
  local err, data = request("recipes/list", {})
  return err, data
end

--- Execute a chat question and get a streaming response
--- Sadly just puts whatever we get as the response into the currently
--- open window... I will fix this later (needs protocol changes)
---@param message string
---@return table | nil
---@return table | nil
execute.chat_question = function(message)
  return request("recipes/execute", { id = "chat-question", humanChatInput = message })
end

vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  callback = function(data)
    ---@type CodyTextDocument
    local document = {
      filePath = data.file,
      content = table.concat(vim.api.nvim_buf_get_lines(data.buf, 0, -1, false), "\n"),
    }

    notify("textDocument/didOpen", document)
  end,
})

return {
  client = client,
  notify = notify,
  request = request,
  initialize = initialize,
  execute = execute,
}

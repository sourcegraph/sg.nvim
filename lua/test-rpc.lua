local async = require "plenary.async"
local void = async.void

local client = vim.lsp.rpc.start("./dist/agent-linux-x64", {}, {
  notification = function(...)
    vim.print("notification", ...)
  end,
})

if not client then
  error "failed!!"
end

local request = async.wrap(client.request, 3)

void(function()
  local err, data = request("initialize", {
    name = "neovim",
    version = "v1",
    workspace_root_path = ".",
  })

  if err ~= nil then
    return
  end

  vim.print("initialized:", data)

  err, data = request("recipes/list", {})
  if err ~= nil then
    return
  end

  vim.print("recipes:", data)

  request("recipes/execute", {
    id = "chat-question",
    human_chat_input = "tell me a joke about javascript",
  })
end)()

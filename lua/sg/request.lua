-- Verify that the environment is properly configured
local creds = require("sg.auth").get()
if not creds then
  return require("sg.notify").NO_AUTH()
end

local bin_sg_nvim = require("sg.config").get_nvim_agent()
if not bin_sg_nvim then
  return require("sg.notify").NO_BUILD()
end

local log = require "sg.log"
local lsp = require "sg.vendored.vim-lsp-rpc"

local M = {}

local notification_handlers = {}
local server_handlers = {}

--- Start the server
---@param opts { force: boolean? }?
---@return VendoredPublicClient?
M.start = function(opts)
  opts = opts or {}

  if M.client and not opts.force then
    return M.client
  end

  if M.client then
    M.client.terminate()
    vim.wait(10)
  end

  M.client = lsp.start(bin_sg_nvim, {}, {
    notification = function(method, data)
      if notification_handlers[method] then
        notification_handlers[method](data)
      else
        log.error("[sg-agent] unhandled method:", method)
      end
    end,
    server_request = function(method, params)
      local handler = server_handlers[method]
      if handler then
        return handler(method, params)
      else
        log.error("[cody-agent] unhandled server request:", method)
      end
    end,
  }, {
    env = {
      PATH = vim.env.PATH,
      SRC_ACCESS_TOKEN = creds.token,
      SRC_ENDPOINT = creds.endpoint,
    },
  })

  if not M.client then
    vim.notify "[sg.nvim] failed to start sg.nvim plugin"
    return nil
  end

  return M.client
end

M.notify = function(...)
  local client = M.start()
  if not client then
    return
  end

  return client.notify(...)
end

M.request = function(method, params, callback)
  local client = M.start()
  if not client then
    return callback("no available client", nil)
  end

  return client.request(method, params, function(err, result)
    return callback(err, result)
  end)
end

return M

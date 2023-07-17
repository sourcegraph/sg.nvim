-- Attempt to clear SG_SG_CLIENT if one is already
-- running currently.
--
-- This should hopefully prevent multiple cody clients from
-- running at a time.
if SG_SG_CLIENT then
  local ok, err = pcall(SG_SG_CLIENT.terminate)
  if not ok then
    vim.notify(string.format("[sg-agent] Attempting to close existing client failed:%s", err))
  end

  SG_SG_CLIENT = nil
end

local env = require "sg.env"
local log = require "sg.log"

local vendored_rpc = require "sg.vendored.vim-lsp-rpc"

local M = {}

local notification_handlers = {}
local server_handlers = {}

local bin_sg_nvim = require("sg.config").get_nvim_agent()
SG_SG_CLIENT = vendored_rpc.start(bin_sg_nvim, {}, {
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
    SRC_ACCESS_TOKEN = env.token(),
    SRC_ENDPOINT = env.endpoint(),
  },
})

if not SG_SG_CLIENT then
  vim.notify "[sg.nvim] failed to start cody-agent"
  return nil
end

M.notify = function(...)
  return SG_SG_CLIENT.notify(...)
end

M.request = require("plenary.async").wrap(function(method, params, callback)
  return SG_SG_CLIENT.request(method, params, function(err, result)
    return callback(err, result)
  end)
end, 3)

return M

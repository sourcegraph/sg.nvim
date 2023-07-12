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

---@type string
local bin_sg_cody = (function()
  local cmd = "sg-cody"
  if vim.fn.executable(cmd) == 1 then
    return cmd
  end

  -- TODO: Should pick the one with the most recent priority?
  local cmd_paths = {
    "target/debug/sg-cody",
    -- "target/release/sg-cody",
    "bin/sg-cody",
  }

  for _, path in ipairs(cmd_paths) do
    local res = vim.api.nvim_get_runtime_file(path, false)[1]
    if res then
      return res
    end
  end

  error "Failed to load sg-cody: You probably did not run `nvim -l build/init.lua`"
end)()

local M = {}

local notification_handlers = {
  ["Echo"] = function(_) end,
}

local server_handlers = {}

SG_SG_CLIENT = vendored_rpc.start(bin_sg_cody, {}, {
  cmd_env = {
    PATH = vim.env.PATH,
    SRC_ACCESS_TOKEN = env.token(),
    SRC_ENDPOINT = env.endpoint(),
  },

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

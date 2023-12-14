local M = {}

local protocol = require "sg.cody.protocol"

local augroup_cody = vim.api.nvim_create_augroup("augroup-cody", {})
local aucmd = function(opts)
  local events = {}
  for _, event in ipairs(opts) do
    table.insert(events, event)
  end

  vim.api.nvim_create_autocmd(events, {
    group = augroup_cody,
    pattern = opts.pattern,
    callback = opts.cb,
  })
end

local on_data = function(cb)
  return function(data)
    cb(data.buf)
  end
end

--- Setup the agent
---@param config sg.config
M.setup = function(config)
  vim.api.nvim_clear_autocmds { group = augroup_cody }

  if config.enable_cody then
    -- Connect protocol messages to neovim events
    aucmd { "BufEnter", cb = on_data(protocol.did_focus) }
    aucmd { "BufDelete", cb = on_data(protocol.did_close) }
    aucmd { "BufReadPost", cb = on_data(protocol.did_open) }
    aucmd { "VimLeavePre", cb = protocol.exit }

    -- TODO: Should add something in the protocol for changing workspace root?
    -- aucmd { "DirChanged", cb = function() end, }
  end
end

return M

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

-- stylua: ignore start
aucmd { "BufEnter", cb = function(data) protocol.did_focus(data.buf) end }
aucmd { "BufDelete", cb = function(data) protocol.did_close(data.buf) end }
aucmd { "BufAdd", "BufReadPost", cb = function(data) protocol.did_open(data.buf) end }
-- stylua: ignore end

aucmd {
  "VimLeavePre",
  cb = function()
    local rpc = require "sg.cody.rpc"
    rpc.shutdown()
    rpc.exit()
  end,
}

-- TODO: Should add something in the protocol for changing workspace root?
-- aucmd { "DirChanged", cb = function() end, }

local async = require "plenary.async"
local void = async.void

local debounce = require "sg.debounce"
local rpc = require "sg.cody.rpc"
local protocol = require "sg.cody.protocol"
if not rpc then
  return
end

void(function()
  -- Run initialize as first message to send
  local _ = rpc.initialize()

  -- And then respond that we've initialized
  local _ = rpc.notify("initialized", {})
end)()

local notify = rpc.notify
local debounce_handles = {}

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

aucmd {
  "BufReadPost",
  cb = function(data)
    local document = protocol.get_text_document(data.buf)
    notify("textDocument/didOpen", document)
  end,
}

aucmd {
  "BufEnter",
  cb = function(data)
    local document = protocol.get_text_document(data.buf, { content = false })
    notify("textDocument/didFocus", document)
  end,
}

aucmd {
  "BufDelete",
  cb = function(data)
    local bufnr = data.buf
    if debounce_handles[bufnr] then
      debounce_handles[bufnr]:close()
    end

    local document = protocol.get_text_document(data.buf, { content = false })
    notify("textDocument/didClose", document)
  end,
}

aucmd {
  "BufAdd",
  cb = function(data)
    local bufnr = data.buf
    if debounce_handles[bufnr] then
      return
    end

    -- TODO: Probably other buffers that we should not send events for
    if vim.bo[bufnr].buflisted == 0 then
      return
    end

    local notify_changes, timer = debounce.debounce_trailing(function()
      local document = protocol.get_text_document(data.buf)
      notify("textDocument/didChange", document)
    end, 500)

    debounce_handles[bufnr] = timer
    vim.schedule(function()
      vim.api.nvim_buf_attach(bufnr, true, {
        on_lines = notify_changes,
      })
    end)
  end,
}

aucmd {
  "VimLeavePre",
  cb = function()
    void(function()
      rpc.shutdown()
      rpc.exit()
    end)()
  end,
}

-- TODO: Should add something in the protocol for changing workspace root
-- aucmd { "DirChanged", cb = function() end, }

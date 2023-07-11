local async = require "plenary.async"
local block_on = require "plenary.async.util"
local void = async.void

local debounce = require "sg.debounce"
local document = require "sg.document"
local rpc = require "sg.cody.rpc"
local protocol = require "sg.cody.protocol"
if not rpc then
  return
end

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
    if not document.is_useful(data.buf) then
      return
    end

    local doc = protocol.get_text_document(data.buf)
    notify("textDocument/didOpen", doc)
  end,
}

aucmd {
  "BufEnter",
  cb = function(data)
    if not document.is_useful(data.buf) then
      return
    end

    local doc = protocol.get_text_document(data.buf, { content = false })
    notify("textDocument/didFocus", doc)
  end,
}

aucmd {
  "BufDelete",
  cb = function(data)
    local bufnr = data.buf
    if debounce_handles[bufnr] then
      local handle = debounce_handles[bufnr]
      if not handle:is_closing() then
        handle:close()
      end
    end

    if not document.is_useful(data.buf) then
      return
    end

    local doc = protocol.get_text_document(data.buf, { content = false })
    if not doc.filePath then
      return
    end

    notify("textDocument/didClose", doc)
  end,
}

aucmd {
  "BufAdd",
  cb = function(data)
    local bufnr = data.buf
    if debounce_handles[bufnr] then
      return
    end

    if not document.is_useful(bufnr) then
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
    local f = async.wrap(function(cb)
      rpc.shutdown()
      cb()
    end, 1)

    block_on(f)

    rpc.exit()
  end,
}

-- TODO: Should add something in the protocol for changing workspace root
-- aucmd { "DirChanged", cb = function() end, }

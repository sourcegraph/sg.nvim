local config = require "sg.config"
local debounce = require "sg.vendored.debounce"
local document = require "sg.document"

local proto = {}

local if_nil = function(x, val)
  if x == nil then
    return val
  end

  return x
end

local bufstate = {}

--- Get textdocument for a buffer
---@param bufnr number
---@param opts table?
---@return CodyTextDocument
proto.get_text_document = function(bufnr, opts)
  if not bufstate[bufnr] then
    bufstate[bufnr] = {}
  end

  opts = opts or {}
  opts.content = if_nil(opts.content, true)
  -- opts.selection = if_nil(opts.selection, false)

  -- TODO: We need to handle renames and some other goofy stuff like that
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    bufstate[bufnr].name = name
  end

  local text_document = {
    filePath = name,
  }

  if opts.content then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    text_document.content = table.concat(lines, "\n")
  end

  -- TODO:
  if opts.selection then
    text_document.selection = opts.selection
  end

  return text_document
end

local debounce_handles = {}

proto.did_open = function(bufnr)
  if debounce_handles[bufnr] then
    return
  end

  if not document.is_useful(bufnr) then
    return
  end

  -- Open the file
  require("sg.cody.rpc").notify("textDocument/didOpen", proto.get_text_document(bufnr))

  -- Notify of changes
  local notify_changes, timer = debounce.debounce_trailing(function()
    require("sg.cody.rpc").notify("textDocument/didChange", proto.get_text_document(bufnr))
  end, 500)

  debounce_handles[bufnr] = timer

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_attach(bufnr, true, {
        on_lines = notify_changes,
      })
    end
  end)
end

proto.did_close = function(bufnr)
  if debounce_handles[bufnr] then
    local handle = debounce_handles[bufnr]
    if not handle:is_closing() then
      handle:close()
    end

    debounce_handles[bufnr] = nil
  end

  if not document.is_useful(bufnr) then
    return
  end

  local doc = proto.get_text_document(bufnr, { content = false })
  if not doc.filePath then
    return
  end

  require("sg.cody.rpc").notify("textDocument/didClose", doc)
end

proto.did_focus = function(bufnr)
  if not document.is_useful(bufnr) then
    return
  end

  require("sg.cody.rpc").notify("textDocument/didFocus", proto.get_text_document(bufnr, { content = false }))
end

proto.exit = function()
  local rpc = require "sg.cody.rpc"

  if not rpc.client then
    return
  end

  rpc.shutdown()
  rpc.exit()
end

return proto

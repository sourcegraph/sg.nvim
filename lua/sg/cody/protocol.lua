local proto = {}

local if_nil = function(x, val)
  if x == nil then
    return val
  end

  return x
end

--- Get textdocument for a buffer
---@param bufnr number
---@param opts table?
---@return CodyTextDocument
proto.get_text_document = function(bufnr, opts)
  opts = opts or {}
  opts.content = if_nil(opts.content, true)
  opts.selection = if_nil(opts.selection, false)

  local file = vim.api.nvim_buf_get_name(bufnr)

  local document = {
    filePath = file,
  }

  if opts.content then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    document.content = table.concat(lines, "\n")
  end

  if opts.selection then
    -- TODO:
  end

  return document
end

return proto

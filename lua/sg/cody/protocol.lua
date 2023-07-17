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
  opts.selection = if_nil(opts.selection, false)

  -- TODO: We need to handle renames and some other goofy stuff like that
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    bufstate[bufnr].name = name
  end

  local document = {
    filePath = name,
  }

  if opts.content then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    document.content = table.concat(lines, "\n")
  end

  -- TODO:
  -- if opts.selection then
  -- end

  return document
end

return proto

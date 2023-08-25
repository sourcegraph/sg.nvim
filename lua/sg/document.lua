local document = {}

--- Determines if buffer is useful
---@param bufnr any
document.is_useful = function(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local bo = vim.bo[bufnr]
  if not bo.buflisted then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if not name or name == "" then
    return false
  end

  return true
end

return document

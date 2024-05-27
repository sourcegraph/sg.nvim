local shared = {}

shared.create = function(bufnr, win, popup_options)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
  end

  if not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_open_win(bufnr, false, popup_options)
  end

  vim.wo[win].wrap = true
  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"

  return bufnr, win
end

shared.buf_del = function(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  return -1
end

shared.win_del = function(win)
  if vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end

  return -1
end

shared.calculate_width = function(width)
  if type(width) == "string" then
    error "i'll do this later"
  elseif width > 1 then
    return math.floor(width)
  else
    return math.floor(width * vim.o.columns)
  end
end

shared.calculate_height = function(height)
  if type(height) == "string" then
    error "i'll do this later"
  elseif height > 1 then
    return height
  else
    return math.floor(height * vim.o.lines)
  end
end

shared.calculate_row = function(row)
  return row
end

shared.calculate_col = function(col)
  return col
end

shared.make_win_minimal = function(win)
  local options = {
    number = false,
    relativenumber = false,
    cursorline = false,
    cursorcolumn = false,
    list = false,
    signcolumn = "auto",
    wrap = true,
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
  }

  for key, value in pairs(options) do
    vim.wo[win][key] = value
  end

  vim.wo[win].statuscolumn = nil
  vim.opt_local.fillchars:append { eob = " " }
end

shared.make_buf_minimal = function(bufnr)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].buftype = "nofile"
end

return shared

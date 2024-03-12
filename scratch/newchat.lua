local width = math.floor(vim.o.columns * 0.9)
local height = math.floor(vim.o.lines * 0.8)

local col = math.floor((vim.o.columns - width) / 2)
local row = math.floor((vim.o.lines - height) / 2) - 2

local prompt_height = 5
local history_height = height - prompt_height

local history_width = width
local prompt_width = width
local settings_width = 0

if width > 50 then
  settings_width = 30
  prompt_width = width - settings_width - 2
end

---@type vim.api.keyset.float_config
local history_opts = {
  relative = "editor",
  border = "rounded",
  width = history_width,
  height = history_height - 2,
  style = "minimal",
  row = row,
  col = col,
}

local history_bufnr = vim.api.nvim_create_buf(false, true)
local history_win = vim.api.nvim_open_win(history_bufnr, true, history_opts)

local prompt_opts = {
  relative = "editor",
  border = "rounded",
  width = prompt_width,
  height = prompt_height,
  style = "minimal",
  row = row + history_height,
  col = col,
}

local settings_win
if settings_width > 0 then
  local settings_opts = {
    relative = "editor",
    border = "rounded",
    width = settings_width,
    height = prompt_height,
    style = "minimal",
    row = row + history_height,
    col = col + prompt_width + 2,
  }

  local settings_bufnr = vim.api.nvim_create_buf(false, true)
  settings_win = vim.api.nvim_open_win(settings_bufnr, true, settings_opts)

  vim.api.nvim_buf_set_lines(settings_bufnr, 0, -1, false, {
    "message: loading",
    "model: GPT-4-turbo",
  })
end

local prompt_bufnr = vim.api.nvim_create_buf(false, true)
local prompt_win = vim.api.nvim_open_win(prompt_bufnr, true, prompt_opts)

vim.api.nvim_create_autocmd("BufLeave", {
  buffer = prompt_bufnr,
  once = true,
  callback = function()
    vim.api.nvim_win_close(prompt_win, true)
    vim.api.nvim_win_close(history_win, true)
    if settings_win then
      vim.api.nvim_win_close(settings_win, true)
    end
  end,
})

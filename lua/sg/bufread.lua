local filetype = require "plenary.filetype"
local log = require "sg.log"

local lib = require "libsg_nvim"

local M = {}

-- TODO: I don't know how to turn off this https://* stuff and not make netrw users mad
pcall(
  vim.cmd,
  [[
  autocmd! Network BufReadCmd https://*
]]
)

vim.cmd [[
  augroup Sourcegraph
    au!
    autocmd BufReadCmd sg://* lua (R or require)("sg.bufread").edit(vim.fn.expand("<amatch>"))
    autocmd BufReadCmd https://sourcegraph.com/* lua (R or require)("sg.bufread").edit(vim.fn.expand("<amatch>"))
  augroup END
]]

M.edit = function(path)
  log.info("BufReadCmd: ", path)

  local remote_file = lib.get_remote_file(path)
  local bufnr = vim.api.nvim_get_current_buf()

  local normalized_bufname = remote_file:bufname()
  local existing_bufnr = vim.fn.bufnr(normalized_bufname)
  if existing_bufnr ~= -1 and bufnr ~= existing_bufnr then
    log.debug("... Already exists", existing_bufnr, normalized_bufname)
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    log.info "... Make a new one"
    if path ~= normalized_bufname then
      vim.api.nvim_buf_set_name(bufnr, normalized_bufname)
    end

    local contents = remote_file:read()
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.cmd [[doautocmd BufRead]]
    vim.api.nvim_buf_set_option(bufnr, "filetype", filetype.detect(remote_file.path))
  end

  if remote_file.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { remote_file.line, remote_file.col or 0 })
  end
end

return M

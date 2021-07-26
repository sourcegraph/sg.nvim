local file = require "sg.file"
local filetype = require "plenary.filetype"
local log = require "sg.log"
local URI = require "sg.uri"

local SP = function(...)
  local args = { ... }
  vim.schedule(function()
    P(unpack(args))
  end)
end

local M = {}

-- TODO: I don't know how to turn off this https://* stuff and not make netrw users mad
pcall(vim.cmd, [[
  autocmd! Network BufReadCmd https://*
]])

vim.cmd [[
  augroup Sourcegraph
    au!
    autocmd BufReadCmd sg://* lua R("sg.bufread").edit(vim.fn.expand("<amatch>"))
    autocmd BufReadCmd https://sourcegraph.com/* lua R("sg.bufread").edit(vim.fn.expand("<amatch>"))
  augroup END
]]

M.edit = function(path)
  log.info("BufReadCmd: ", path)

  local uri = URI:new(path)

  local bufnr = vim.api.nvim_get_current_buf()

  local normalized_bufname = uri:bufname()
  local existing_bufnr = vim.fn.bufnr(normalized_bufname)
  log.info "existing check..."
  if existing_bufnr ~= -1 and bufnr ~= existing_bufnr then
    log.info("... Already exists", existing_bufnr, normalized_bufname)
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    log.info "... Make a new one"
    if path ~= normalized_bufname then
      vim.api.nvim_buf_set_name(bufnr, normalized_bufname)
    end

    local remote = uri.remote
    local commit = uri.commit
    local filepath = uri.filepath

    local contents = file.read(remote, commit, filepath)
    contents = vim.split(contents, "\n")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.cmd [[doautocmd BufRead]]
    vim.api.nvim_buf_set_option(bufnr, "filetype", filetype.detect(filepath))
  end

  if uri.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { uri.line, uri.col or 0 })
  end
end

return M

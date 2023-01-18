local filetype = require "plenary.filetype"
local log = require "sg.log"
local lsp = require "sg.lsp"

local lib = require "libsg_nvim"

local M = {}

-- TODO: I don't know how to turn off this https://* stuff and not make netrw users mad
pcall(vim.api.nvim_clear_autocmds, {
  group = "Network",
  event = "BufReadCmd",
  pattern = "https://*",
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("sourcegraph-bufread", { clear = true }),
  pattern = { "sg://*", "https://sourcegraph.com/*" },
  callback = function()
    M.edit(vim.fn.expand "<amatch>")
  end,
})

M.edit = function(path)
  local ok, remote_file = pcall(lsp.get_remote_file, path)
  if not ok then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "failed to load file" })
    return
  end

  if not remote_file then
    log.info "Failed to read remote file"
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  local normalized_bufname = remote_file:bufname()
  local existing_bufnr = vim.fn.bufnr(normalized_bufname)
  if existing_bufnr ~= -1 and bufnr ~= existing_bufnr then
    log.debug("... Already exists", existing_bufnr, normalized_bufname)
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    if path ~= normalized_bufname then
      vim.api.nvim_buf_set_name(bufnr, normalized_bufname)
    end

    local ok, contents = pcall(lib.get_remote_file_contents, remote_file.remote, remote_file.commit, remote_file.path)
    if not ok then
      vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "failed to get contents" })
      vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
      return
    end

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.cmd [[doautocmd BufRead]]
    vim.api.nvim_buf_set_option(bufnr, "filetype", filetype.detect(remote_file.path))

    -- TODO: I don't love calling this directly here...
    --  But I'm not sure *why* it doesn't attach using autocmds and listening
    require("sg.lsp").attach(bufnr)
  end

  if remote_file.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { remote_file.line, remote_file.col or 0 })
  end
end

return M

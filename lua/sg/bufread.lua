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

local sg_lsp_id = nil

local group = vim.api.nvim_create_augroup("sg.nvim", { clear = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = group,
  pattern = { "https://sourcegraph.com/*", "sg://*" },
  callback = function()
    if not sg_lsp_id then
      local cmd = vim.api.nvim_get_runtime_file("target/debug/sg-lsp", false)[1]
      sg_lsp_id = vim.lsp.start_client {
        cmd = { cmd },
        name = "sg-lsp",
        on_attach = require("sg.lsp").on_attach,
        cmd_env = {
          SRC_ACCESS_TOKEN = os.getenv "SRC_ACCESS_TOKEN",
          SRC_ENDPOINT = os.getenv "SRC_ENDPOINT",
        },
      }

      print("LSP: ", sg_lsp_id)
    end

    require("sg.bufread").edit(vim.fn.expand "<amatch>")
  end,
})

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

    local contents = lib.get_remote_file_contents(remote_file.remote, remote_file.commit, remote_file.path)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.cmd [[doautocmd BufRead]]
    vim.api.nvim_buf_set_option(bufnr, "filetype", filetype.detect(remote_file.path))
  end

  if remote_file.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { remote_file.line, remote_file.col or 0 })
  end

  vim.lsp.buf_attach_client(bufnr, sg_lsp_id)
end

return M

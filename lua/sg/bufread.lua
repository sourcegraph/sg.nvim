local filetype = require "plenary.filetype"
local log = require "sg.log"
local lib = require "sg.lib"

local M = {}

local get_path_info = function(path)
  return lib.get_path_info(path)
end

M.edit = function(path)
  local ok, path_info = pcall(get_path_info, path)
  if not ok then
    local contents = {}
    if type(path_info) == "string" then
      contents = vim.split(path_info, "\n")
    else
      table.insert(contents, tostring(path_info))
    end

    table.insert(contents, 1, "failed to load file")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, contents)
    return
  end

  if not path_info then
    log.info "Failed to retrieve path info"
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  if path_info.type == "directory" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "not yet handling directories..." })
    return
  end

  local remote_file = path_info.data
  local bufname = remote_file.bufname
  local existing_bufnr = vim.fn.bufnr(bufname)
  if existing_bufnr ~= -1 and bufnr ~= existing_bufnr then
    log.debug("... Already exists", existing_bufnr, bufname)
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    if path ~= bufname then
      vim.api.nvim_buf_set_name(bufnr, bufname)
    end

    local ok, contents = pcall(lib.get_remote_file_contents, remote_file.remote, remote_file.oid, remote_file.path)
    if not ok then
      local errmsg
      if type(contents) == "string" then
        errmsg = vim.split(contents, "\n")
      else
        errmsg = vim.split(tostring(contents), "\n")
      end

      table.insert(errmsg, 1, "failed to get contents")

      vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, errmsg)
      vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
      return
    end

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.cmd [[doautocmd BufRead]]
    vim.api.nvim_buf_set_option(bufnr, "filetype", filetype.detect(remote_file.path, {}))

    -- TODO: I don't love calling this directly here...
    --  But I'm not sure *why* it doesn't attach using autocmds and listening
    require("sg.lsp").attach(bufnr)
  end

  if remote_file.position then
    error "TODO: handle position"
    -- pcall(vim.api.nvim_win_set_cursor, 0, { remote_file.line, remote_file.col or 0 })
  end
end

return M

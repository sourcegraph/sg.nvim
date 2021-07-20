local file = R "sg.file"
local filetype = require "plenary.filetype"

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

local deconstruct_path = function(original)
  local path = original
  path = string.gsub(path, "https://sourcegraph.com/", "sg://")
  path = string.gsub(path, "sg://", "")

  local split_path = vim.split(path, "-")
  local url_with_commit = split_path[1]
  local url, commit = unpack(vim.split(url_with_commit, "@"))

  -- Clear trailing slash, src-cli doesn't like it very much
  if string.sub(url, #url) == "/" then
    url = string.sub(url, 1, -2)
  end

  if commit then
    commit = string.gsub(commit, "/", "")
  end

  table.remove(split_path, 1)
  local path_and_args = string.sub(table.concat(split_path, "-"), 2)
  -- change ^/tree/ -> blob or just remove it straight up
  path_and_args = string.gsub(path_and_args, "^/blob/", "/")
  path_and_args = string.gsub(path_and_args, "^blob/", "")

  local filepath, args = unpack(vim.split(path_and_args, "?", true))

  local line, col
  if args then
    local raw_line, raw_col = unpack(vim.split(args, ":"))
    if raw_line then
      line = tonumber((string.gsub(raw_line, "L", "")))
    end

    if raw_col then
      col = tonumber(raw_col)
    end
  end

  return {
    url = url,
    commit = commit,
    filepath = filepath,
    line = line,
    col = col,
  }
end

local construct_path = function(url, commit, filepath)
  filepath = string.gsub(filepath, "^/blob/", "/")
  filepath = string.gsub(filepath, "^blob/", "")

  local commit_str = ""
  if commit then
    -- change this to just first five of commit hash if it's all hash like
    commit_str = string.format("@%s", commit)
  end

  -- shorten github.com/ -> gh/
  return string.format("sg://%s%s/-/%s", url, commit_str, filepath)
end

local normalize_path = function(path)
  local parts = deconstruct_path(path)
  return construct_path(parts.url, parts.commit, parts.filepath)
end

M.edit = function(path)
  local parts = deconstruct_path(path)

  local bufnr = vim.api.nvim_get_current_buf()

  local normalized = normalize_path(path)
  local existing_bufnr = vim.fn.bufnr(normalized)
  if existing_bufnr ~= -1 then
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    if path ~= normalized then
      vim.api.nvim_buf_set_name(bufnr, normalized)
    end

    local url = parts.url
    local commit = parts.commit
    local filepath = parts.filepath

    local contents = file.read(url, commit, filepath)
    contents = vim.split(contents, "\n")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.cmd [[doautocmd BufRead]]
    vim.api.nvim_buf_set_option(bufnr, "filetype", filetype.detect(filepath))
  end

  if parts.line then
    vim.api.nvim_win_set_cursor(0, { parts.line, parts.col or 0 })
  end
end

M._construct_path = construct_path
M._deconstruct_path = deconstruct_path

return M

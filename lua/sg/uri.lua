---@class URI
---@field remote string: The remote that this file points to
---@field commit string: The commit hash or tag name
---@field filepath string: The relative filepath within the git repo. Does not start with /
---@field line number?: The number, optional
---@field col number?: The number, optional
local URI = {}
URI.__index = URI

local trim_protocol_prefixes = function(text)
  text = string.gsub(text, "https://sourcegraph.com/", "")
  text = string.gsub(text, "sg://", "")

  return text
end

local normalize_remote = function(remote)
  -- Clear trailing slash, src-cli doesn't like it very much
  if string.sub(remote, #remote) == "/" then
    remote = string.sub(remote, 1, -2)
  end

  -- Remove any beginning slashes
  remote = string.gsub(remote, "^/", "")

  -- Sub gh/ -> github.com/
  remote = string.gsub(remote, "^gh/", "github.com/")

  return remote
end

local normalize_commit = function(commit)
  -- TODO: if it's an incomplete hash, we can ask for matching hashes somehow?

  if commit then
    commit = string.gsub(commit, "/", "")
  end

  return commit
end

local remove_starting_segment = function(str, seg)
  str = string.gsub(str, "^/" .. seg .. "/", "/")
  str = string.gsub(str, "^" .. seg .. "/", "")

  return str
end

local normalize_filepath = function(filepath)
  filepath = remove_starting_segment(filepath, "blob")
  filepath = remove_starting_segment(filepath, "tree")

  return filepath
end

local normalize_args = function(args)
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

  return line, col
end

--- Get a new URI
--- Examples to convert
-- https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c
-- https://sourcegraph.com/github.com/neovim/neovim/-/tree/src/nvim/autocmd.c
-- sg://github.com/neovim/neovim/-/blob/src/nvim/autocmd.c
-- sg://github.com/neovim/neovim/-/tree/src/nvim/autocmd.c
-- sg://gh/neovim/neovim/-/blob/src/nvim/autocmd.c
-- sg://gh/neovim/neovim/-/tree/src/nvim/autocmd.c
-- sg://github.com/neovim/neovim/-/src/nvim/autocmd.c
-- sg://gh/neovim/neovim/-/src/nvim/autocmd.c
---@return URI
function URI:new(text)
  local raw = text
  text = trim_protocol_prefixes(text)

  local split_path = vim.split(text, "-")

  local remote_with_commit = table.remove(split_path, 1)
  local remote, commit = unpack(vim.split(remote_with_commit, "@"))

  remote = normalize_remote(remote)
  commit = normalize_commit(commit)

  local path_and_args = string.sub(table.concat(split_path, "-"), 2)
  local filepath, args = unpack(vim.split(path_and_args, "?", true))

  filepath = normalize_filepath(filepath)

  local line, col = normalize_args(args)

  return setmetatable({
    _raw = raw,

    remote = remote,
    commit = commit,
    filepath = filepath,
    line = line,
    col = col,
  }, self)
end

function URI:bufname()
  local remote = self.remote
  local commit = self.commit
  local filepath = self.filepath

  return self._construct_bufname(remote, commit, filepath)
end

local bufname_remote = function(remote)
  remote = string.gsub(remote, "^/", "")
  remote = string.gsub(remote, "^github.com/", "gh/")

  return remote
end

local bufname_commit = function(commit)
  if commit then
    commit = normalize_commit(commit)

    -- TODO: Check that this matches w/ a commit hash, not a branch name
    -- TODO: Make sure this is not an ambiguous commit hash
    commit = string.sub(commit, 1, 8)
  end

  return commit
end
local bufname_filepath = normalize_filepath

function URI._construct_bufname(remote, commit, filepath)
  remote = bufname_remote(remote)
  commit = bufname_commit(commit)
  filepath = bufname_filepath(filepath)

  local commit_str = ""
  if commit then
    -- change this to just first five of commit hash if it's all hash like
    commit_str = string.format("@%s", commit)
  end

  -- shorten github.com/ -> gh/
  return string.format("sg://%s%s/-/%s", remote, commit_str, filepath)
end

return URI

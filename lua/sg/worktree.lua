local Job = require "plenary.job"
local Path = require "plenary.path"

local log = require "sg.log"

local worktree = {}

worktree._base = Path:new(vim.fn.stdpath "cache", "sg_telescope")

worktree.transform_remote = function(remote_url)
  return (remote_url:gsub("https://", ""):gsub("/", "__"))
end

worktree.repo_path = function(remote_url)
  local bare = Path:new(worktree._base, worktree.transform_remote(remote_url))

  if not bare:exists() then
    -- TODO: This takes a long time on some things...
    local clone = Job:new { "git", "clone", "--bare", remote_url, bare:absolute() }
    clone:sync(40000)

    if clone.code ~= 0 then
      log.warn("Failed to sync", clone)
      error(string.format("... %s %s", remote_url, bare:absolute()))
    end
  else
    log.debug("repo_path exists:", bare:absolute())
  end

  return bare
end

worktree.fetch = function(remote_url)
  local bare = Path:new(worktree._base, worktree.transform_remote(remote_url))
  local fetch = Job:new { "git", "fetch", "--all", cwd = bare:absolute() }
  local output = fetch:sync()
  log.info("fetched:", output, fetch:stderr_result())
end

worktree.commit_path = function(remote_url, commit_hash)
  local bare = worktree.repo_path(remote_url)
  local commit_path = Path:new(bare, commit_hash)

  if not commit_path:exists() then
    log.info("... Checking out commit", commit_hash)
    local add = Job:new { "git", "worktree", "add", commit_hash, commit_hash, cwd = bare:absolute() }
    local output = add:sync()

    if not commit_path:exists() then
      worktree.fetch(remote_url)
      add:sync()
    end

    assert(commit_path:exists(), "Failed to create path")
  else
    log.debug("tree already added: ", commit_hash)
  end

  return commit_path
end

worktree.edit = function(remote_url, commit_hash, path)
  local commit_path = worktree.commit_path(remote_url, commit_hash)
  local file_path = Path:new(commit_path, path)

  log.info("File Path:", file_path:absolute())
  log.info("Exists   ?", file_path:exists())

  vim.cmd([[vnew ]] .. file_path:absolute())

  -- TODO:
  -- set options for readonly
  -- set local working directory
end

return worktree

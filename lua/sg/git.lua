local Job = require "plenary.job"

local git = {}

local get_single_line = function(t)
  return Job:new(t):sync()[1]
end

git.default_remote_url = function(cwd)
  return get_single_line {
    "git",
    "remote",
    "get-url",
    get_single_line { "git", "remote", cwd = cwd },

    cwd = cwd,
  }
end

-- Creates new worktree at that commit w/ that commit info
-- git worktree add 04097305904e48788eeb911ddf0f5f131ad66845 04097305904e48788eeb911ddf0f5f131ad66845

local url = git.default_remote_url():gsub("https://", ""):gsub("/", "__")
print(url)

return git

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

return git

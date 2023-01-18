local Job = require "plenary.job"

local cli = require "sg.cli"
local log = require "sg.log"

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

local CommitGraphQL = [[
query ($repository: String!, $rev: String!) {
  repository(name: $repository) {
    commit(rev: $rev) {
      oid
    }
  }
}
]]

git.resolve_commit_hash = function(repository, rev)
  -- TODO: I don't know if this is a bad hack... but I'd like to skip
  -- the request if possible...
  --
  -- who has 40 character length branch names?
  -- if #rev == 40 then
  --   return rev
  -- end

  local output = cli.api(CommitGraphQL, {
    repository = repository,
    rev = rev or "HEAD",
  })

  log.trace("resolve commit hash:", output)

  local keypath = { "data", "repository", "commit", "oid" }
  local data = output
  for _, key in ipairs(keypath) do
    if not data then
      error(string.format("something went wrong: %s -> %s", key, data, vim.inspect(output)))
    end

    data = data[key]
  end

  return data
end

return git

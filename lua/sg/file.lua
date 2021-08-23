-- local Job = require "plenary.job"
local Path = require "plenary.path"

local cli = require "sg.cli"
local git = require "sg.git"
local log = require "sg.log"
local once = require("sg.utils").once

local cache_location = vim.fn.stdpath "cache"

local make_filename = function(remote, hash, path)
  remote = string.gsub(remote, "/", "_")
  path = string.gsub(path, "/", "_")
  return string.format("%s__%s__%s", remote, hash, path)
end

local get_cached_path = function(remote, hash, path)
  return Path:new(cache_location, "sg", make_filename(remote, hash, path))
end

local file = {}

file._write_cache = function(remote, hash, path, contents)
  return get_cached_path(remote, hash, path):write(contents, "w")
end

file._has_cache = function(remote, hash, path)
  return get_cached_path(remote, hash, path):exists()
end

file._read_cache = function(remote, hash, path)
  return get_cached_path(remote, hash, path):read()
end

file.read = function(remote, hash, path)
  -- TODO: Decide if we should do this conversion even earlier.
  -- Could make things a lot simpler thinking about how this works.
  hash = git.resolve_commit_hash(remote, hash)

  local content = nil
  if not file._has_cache(remote, hash, path) then
    log.info "Requesting file..."
    local query = string.format("repo:^%s$", remote)
    if hash then
      query = query .. string.format("@%s", hash)
    end
    query = query .. string.format(" file:^%s$", path)

    log.info("query:", query)

    local output = cli.search(query)
    if not output.Results then
      error("no results: " .. vim.inspect(output))
    end

    local first = output.Results[1]
    if not first then
      error("no first: " .. vim.inspect(output))
    end

    if not first.file then
      error("no file: " .. vim.inspect(first))
    end

    content = first.file.content
    file._write_cache(remote, hash, path, content)
  else
    log.info "Reading file..."
    content = file._read_cache(remote, hash, path)
  end

  return vim.split(content, "\n", true)
end

return file

-- local Job = require "plenary.job"
local Path = require "plenary.path"

local cli = require "sg.cli"
local git = require "sg.git"
local log = require "sg.log"
local once = require("sg.utils").once

local cache_location = vim.fn.stdpath "cache"
local checked_base = false

local make_filename = function(remote, hash, path)
  remote = string.gsub(remote, "/", "_")
  path = string.gsub(path, "/", "_")
  return string.format("%s__%s__%s", remote, hash, path)
end

local get_cached_path = function(remote, hash, path)
  local base = Path:new(cache_location, "sg")
  if not checked_base and not base:exists() then
    base:mkdir()
  end

  checked_base = true
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

file._make_query = function(remote, hash, path)
  return string.format("repo:^%s$@%s file:^%s$", remote, hash, path)
end

file.ensure_cache = function(remote, hash, path)
  if file._has_cache(remote, hash, path) then
    log.trace("File already cached:", remote, hash, path)
    return
  end

  local query = file._make_query(remote, hash, path)
  local search = cli.search_async(query, {
    on_exit = vim.schedule_wrap(function(self, ...)
      local output = vim.fn.json_decode(self:result())
      local first = output.Results[1]
      if not first or not first.file then
        error "Failed to get stuff here. TODO"
      end

      log.trace("ensure_cache:", remote, hash, path)
      file._write_cache(remote, hash, path, first.file.content)
    end),
  })

  return search
end

file.read = function(remote, hash, path)
  assert(remote, "Must have a remote")
  assert(hash, "Must have a hash")
  assert(path, "Must have a path")

  local content = nil
  if not file._has_cache(remote, hash, path) then
    log.info("Requesting file: ", path)
    local query = file._make_query(remote, hash, path)

    log.debug("file.read query:", query)

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
    log.info("Reading file from disk:", path)
    content = file._read_cache(remote, hash, path)
  end

  return vim.split(content, "\n", true)
end

return file

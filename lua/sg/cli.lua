local Job = require "plenary.job"

local log = require "sg.log"
local once = require("sg.utils").once

local src_cli = vim.fn.exepath "src"

local get_access_token = once(function()
  return os.getenv "SRC_ACCESS_TOKEN"
end)

local get_endpoint = once(function()
  return os.getenv "SRC_ENDPOINT"
end)

local M = {}

M.search = function(query, opts)
  opts = opts or {}

  local j = Job:new {
    src_cli,
    "search",
    "-json",
    query,

    env = {
      SRC_ACCESS_TOKEN = opts.access_token or get_access_token(),
      SRC_ENDPOINT = opts.endpoint or get_endpoint(),
    },
  }

  local output = j:sync()
  log.trace("search output:", output)

  return vim.fn.json_decode(output)
end

M.api = function(request, vars, opts)
  opts = opts or {}

  local j = Job:new {
    src_cli,
    "api",
    "-query",
    request,
    "-vars",
    vim.fn.json_encode(vars or {}),

    env = {
      SRC_ACCESS_TOKEN = opts.access_token or get_access_token(),
      SRC_ENDPOINT = opts.endpoint or get_endpoint(),
    },
  }

  local output = j:sync()
  log.trace("api output:", output)

  output = vim.fn.json_decode(output)
  if output.errors and #output.errors > 0 then
    error(string.format("Error handling request. Got: %s", vim.inspect(output.errors)))
  end

  log.trace("from request:", request)
  log.trace("with vars:", vars)

  return output
end

return M

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

M.search_async = function(query, opts)
  opts = opts or {}

  log.trace("search request:", "query", query)
  local j = Job:new {
    src_cli,
    "search",
    "-json",
    query,

    env = {
      HOME = vim.env.HOME,
      USER = vim.env.USER,

      SRC_ACCESS_TOKEN = opts.access_token or get_access_token(),
      SRC_ENDPOINT = opts.endpoint or get_endpoint(),
    },

    on_exit = opts.on_exit,
  }

  j:start()

  return j
end

M.search = function(query, opts)
  local j = M.search_async(query, opts)
  j:wait()

  local output = j:result()
  log.trace("search output:", output)

  return vim.fn.json_decode(output)
end

M.api_async = function(request, vars, opts)
  opts = opts or {}

  local encoded_vars = vim.fn.json_encode(vars or {})

  log.trace("api request:", "query", request, "vars", encoded_vars)
  local j = Job:new {
    src_cli,
    "api",
    "-query",
    request,
    "-vars",
    encoded_vars,

    env = {
      HOME = vim.env.HOME,
      USER = vim.env.USER,

      SRC_ACCESS_TOKEN = opts.access_token or get_access_token(),
      SRC_ENDPOINT = opts.endpoint or get_endpoint(),
    },
  }

  j:start()

  return j
end

M.api = function(request, vars, opts)
  local j = M.api_async(request, vars, opts)
  j:wait()

  local output = j:result()
  log.trace("api output:", output)
  log.trace("for sebl:", j)

  output = vim.fn.json_decode(output)
  if output.errors and #output.errors > 0 then
    error(string.format("Error handling request. Got: %s", vim.inspect(output.errors)))
  end

  log.trace("from request:", request)
  log.trace("with vars:", vars)

  return output
end

return M

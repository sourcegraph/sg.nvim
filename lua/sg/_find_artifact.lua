local uv = vim.loop or vim.uv

local utils = require "sg.utils"
local M = {}

local sg_root = vim.fn.fnamemodify(require("plenary.debug_utils").sourced_filepath(), ":p:h:h:h")

local sort_by_time = function(candidates)
  table.sort(candidates, function(a, b)
    return a.stat.mtime.sec > b.stat.mtime.sec
  end)
end

M.find_rust_bin = function(cmd)
  if vim.fn.executable(cmd) == 1 then
    return cmd
  end

  local directories = {
    "/target/debug/",
    "/target/release/",
    "/bin/",
  }

  local candidates = {}
  for _, dir in ipairs(directories) do
    local path = utils.joinpath(sg_root, dir, cmd)
    local stat = uv.fs_stat(path)
    if stat then
      table.insert(candidates, { stat = stat, path = path })
    end
  end

  sort_by_time(candidates)
  local result = candidates[1]
  if not result then
    error(string.format("Failed to load %s: You probably did not run `nvim -l build/init.lua`", cmd))
  end

  return result.path
end

M.find_rust_lib = function(name)
  local ok, lib = pcall(require, name)
  if ok then
    return lib
  end

  local libname = "luaopen_" .. name

  local candidates = {}

  local directories = { "/target/debug/", "/target/release/", "/lib/" }
  local suffixes = { ".so", ".dylib" }
  for _, dir in ipairs(directories) do
    for _, suffix in ipairs(suffixes) do
      local path = utils.joinpath(sg_root, dir, name .. suffix)
      local stat = uv.fs_stat(path)
      if stat then
        table.insert(candidates, { stat = stat, path = path })
      end
    end
  end

  sort_by_time(candidates)
  for _, candidate in ipairs(candidates) do
    local dll = package.loadlib(candidate.path, libname)
    if dll then
      local loaded = dll()
      loaded._library_path = candidate.path
      return loaded
    end
  end

  error(string.format("Failed to load %s: You probably did not run `nvim -l build/init.lua`", name))
end

return M

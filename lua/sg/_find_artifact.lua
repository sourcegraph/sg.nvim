local uv = vim.loop or vim.uv

local utils = require "sg.utils"
local M = {}

local sg_root = vim.fn.fnamemodify(require("plenary.debug_utils").sourced_filepath(), ":p:h:h:h")

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

  table.sort(candidates, function(a, b)
    return a.stat.mtime.sec > b.stat.mtime.sec
  end)

  local result = candidates[1]
  if not result then
    error(string.format("Failed to load %s: You probably did not run `nvim -l build/init.lua`", cmd))
  end

  return result.path
end

return M

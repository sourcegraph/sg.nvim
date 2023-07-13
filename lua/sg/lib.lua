-- Force environment variables when loading the library
vim.env.SRC_ACCESS_TOKEN = vim.env.SRC_ACCESS_TOKEN or require("sg.env").token()
vim.env.SRC_ENDPOINT = vim.env.SRC_ENDPOINT or require("sg.env").endpoint()

-- Add the compiled version of the library to our cpath,
-- so that we can require it
local root_dir = vim.fn.fnamemodify(require("plenary.debug_utils").sourced_filepath(), ":p:h:h:h")

-- Reset to original package cpath, we don't want to modify global state
-- for everything just to load this
local original_package_cpath = package.cpath

local find_sgnvim = function(pattern)
  local filepath = root_dir .. pattern
  if not string.find(package.cpath, filepath, 1, true) then
    package.cpath = filepath .. ";" .. package.cpath
  end

  local ok, lib = pcall(require, "libsg_nvim")

  -- Reset package.cpath to original value before returning
  package.cpath = original_package_cpath

  if ok then
    return lib
  end

  return nil
end

local ok, lib = pcall(require, "libsg_nvim")
if ok then
  return lib
end

local patterns = {
  "/target/debug/?.so",
  "/target/debug/?.dylib",

  "/target/release/?.so",
  "/target/release/?.dylib",

  "/lib/?.so",
  "/lib/?.dylib",
}

for _, pattern in ipairs(patterns) do
  lib = find_sgnvim(pattern)
  if lib then
    return lib
  end
end

print "Failed to load libsg_nvim: You probably did not run `nvim -l build/init.lua`"
return {}

-- Add the compiled version of the library to our cpath,
-- so that we can require it
local root_dir = vim.fn.fnamemodify(require("plenary.debug_utils").sourced_filepath(), ":p:h:h:h")

local add_pattern = function(pattern)
  local filepath = root_dir .. pattern
  if not string.find(package.cpath, filepath, 1, true) then
    package.cpath = filepath .. ";" .. package.cpath
  end
end

add_pattern "/target/debug/?.so"
add_pattern "/target/debug/?.dylib"
add_pattern "/target/release/?.so"
add_pattern "/target/release/?.dylib"

add_pattern "/lib/?.so"
add_pattern "/lib/?.dylib"

-- Return the required libsg_nvim

local ok, mod = pcall(require, "libsg_nvim")
if not ok then
  print "Failed to load libsg_nvim: You probably did not run `cargo build --workspace`"
  return {}
end

return mod

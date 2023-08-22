local ok, _ = pcall(require, "cmp")
if not ok then
  return
end

-- Load the source, make it available to users
require "sg.extensions.cmp"

-- Only enable the extension if nvim cmp is installed
local ok, _ = pcall(require, "cmp")
if not ok then
  return
end

-- Set a default color for Cody
vim.api.nvim_set_hl(0, "CmpItemKindCody", { link = "Include", default = true })

-- Load the source, make it available to users
require "sg.extensions.cmp"

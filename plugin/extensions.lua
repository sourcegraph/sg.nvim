-- Check if nvim cmp is installed.
local cmp_ok, _ = pcall(require, "cmp")
if cmp_ok then
  -- Set a default color for Cody
  vim.api.nvim_set_hl(0, "CmpItemKindCody", { link = "Include", default = true })

  -- Load the source, make it available to users
  require "sg.extensions.cmp"
end

-- Check if blink cmp is installed.
local blink_ok, _ = pcall(require, "blink.cmp")
if blink_ok then
  -- Load the source, make it available to users
  require "sg.extensions.blink"
end

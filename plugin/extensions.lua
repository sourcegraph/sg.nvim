-- Only enable the extension if nvim cmp is installed
if pcall(require, "cmp") then
  -- Set a default color for Cody
  vim.api.nvim_set_hl(0, "CmpItemKindCody", { link = "Include", default = true })

  -- Load the source, make it available to users
  require "sg.extensions.cmp"
end

vim.opt.rtp:append "/home/tjdevries/plugins/sg.nvim/packages/coc-cody"

(loadfile "./scripts/init.lua")()

-- Setup sg with defaults
require("sg").setup { accept_tos = true }

-- tree-sitter-lua docgen
local _ = require "docgen.transformers"
local docgen = require "docgen"

-- TODO: Fix the other files so that we can add them here.
local input_files = {
  "./lua/sg/init.lua",
  "./lua/sg/config.lua",
  "./lua/sg/ratelimit.lua",
  "./lua/sg/auth.lua",
  "./lua/sg/cody/plugin/commands.lua",
  "./lua/sg/cody/commands.lua",
  "./plugin/sg.lua",
  "./lua/sg/rpc.lua",
  "./lua/sg/extensions/cmp.lua",
  "./lua/sg/cody/complete.lua",
}

local output_file = "./doc/sg.txt"
local output_file_handle = assert(io.open(output_file, "w"), "open file")

for _, input_file in ipairs(input_files) do
  docgen.write(input_file, output_file_handle)
end

output_file_handle:write " vim:tw=78:ts=8:ft=help:norl:\n"
output_file_handle:close()
vim.cmd [[checktime]]

-- Setup telescope with defaults
(R or require)("sg").setup()

-- tree-sitter-lua docgen
local _ = (R or require) "docgen.transformers"
local docgen = (R or require) "docgen"

-- TODO: Fix the other files so that we can add them here.
local input_files = {
  "./lua/sg/init.lua",
  "./plugin/cody.lua",
}

local output_file = "./doc/sg.txt"
local output_file_handle = assert(io.open(output_file, "w"), "open file")

for _, input_file in ipairs(input_files) do
  docgen.write(input_file, output_file_handle)
end

output_file_handle:write " vim:tw=78:ts=8:ft=help:norl:\n"
output_file_handle:close()
vim.cmd [[checktime]]

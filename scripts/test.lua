(loadfile "./scripts/init.lua")()

local path = "lua/tests/"
local sg_spec_path = require('plenary.path').new(path .. "sg_spec.lua")
local paths_to_run = require('plenary.test_harness')._find_files_to_run(path)

print((function()
    local plenary_dir = vim.fn.fnamemodify(debug.getinfo(1).source:match "@?(.*[/\\])", ":p:h:h:h")
    local rv = vim.inspect {
        plenary_dir = plenary_dir,
        paths_to_run = paths_to_run,
        rtp =
            "set rtp+=.," .. vim.fn.escape(plenary_dir, " ") .. " | runtime plugin/plenary.vim",
        dash_c = string.format(
            'lua require("plenary.busted").run("%s")',
            sg_spec_path:absolute():gsub("\\", "\\\\")
        ),

    }
    return rv
end)())
require("plenary.test_harness").test_directory("lua/tests/", { minimal = "./scripts/init.lua" })

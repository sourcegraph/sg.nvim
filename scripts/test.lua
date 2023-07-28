(loadfile "./scripts/init.lua")()

local path = "lua/tests/"
local sg_spec_path = require('plenary.path').new(path .. "sg_spec.lua")
local paths_to_run = require('plenary.test_harness')._find_files_to_run(path)

print((function()
    local plenary_dir = vim.fn.fnamemodify(debug.getinfo(1).source:match "@?(.*[/\\])", ":p:h:h:h")
    local env = require "sg.env"
    local log = require "sg.log"
    local vendored_rpc = require "sg.vendored.vim-lsp-rpc"

    local rpc = require 'sg.rpc'


    local rv = vim.inspect {
        env = env,
        log = log,
        vendored_rpc = vendored_rpc,
        rpc = rpc,
    }
    return rv
end)())
require("plenary.test_harness").test_directory("lua/tests/", { minimal = "./scripts/init.lua" })

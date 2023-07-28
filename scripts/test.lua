(loadfile "./scripts/init.lua")()

print((function()
    local env = require "sg.env"
    local log = require "sg.log"
    local vendored_rpc = require "sg.vendored.vim-lsp-rpc"

    local rpc = require 'sg.rpc'


    local rv = vim.inspect {
        nvim_cmd_parent = vim.v.progpath,
        env = env,
        log = log,
        vendored_rpc = vendored_rpc,
        rpc = rpc,
    }
    return rv
end)())
require("plenary.test_harness").test_directory("lua/tests/", { minimal = "./scripts/init.lua" })

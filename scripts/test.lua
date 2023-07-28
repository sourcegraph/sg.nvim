(loadfile "./scripts/init.lua")()

print('manifest=' .. vim.env.NVIM_SYSTEM_RPLUGIN_MANIFEST)

print((function()
    local env = require "sg.env"
    local log = require "sg.log"
    local vendored_rpc = require "sg.vendored.vim-lsp-rpc"



    print(vim.inspect(vim.v.argv))
    local rv = vim.inspect {
        nvim_cmd_parent = vim.v.progpath,
        cody_agent = require('sg.config').cody_agent,
        env = env,
        log = log,
        vendored_rpc = vendored_rpc,
    }
    return rv
end)())
require("plenary.test_harness").test_directory("lua/tests/", { minimal = "./scripts/init.lua" })

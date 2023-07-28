print("in sg_spec.lua")
require("plenary.async").tests.add_to_env()
print("before eq")
local eq = assert.are.same

print("before rpc")
local rpc = require "sg.rpc"
print("after rpc")
--
-- describe("sg-agent", function()
--   a.it("can send echo request", function()
--     local _, echoed = rpc.echo "hello"
--     eq("hello", echoed.message)
--   end)
-- end)

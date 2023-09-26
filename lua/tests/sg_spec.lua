require("plenary.async").tests.add_to_env()
local eq = assert.are.same

local rpc = require "sg.rpc"

describe("sg-agent", function()
  a.it("can send echo request", function()
    local err, echoed
    rpc.echo("hello", nil, function(err_, echoed_)
      err = err_
      echoed = echoed_
    end)

    vim.wait(1000, function()
      return err or echoed
    end, 5)

    eq(nil, err)
    eq("hello", echoed.message)
  end)
end)

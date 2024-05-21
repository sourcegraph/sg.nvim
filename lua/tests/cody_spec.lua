vim.cmd [[runtime! after/plugin/cody.lua]]
vim.cmd [[runtime! after/plugin/cody-agent.lua]]

require("plenary.async").tests.add_to_env()

local rpc = assert(require "sg.cody.rpc", "able to load cody rpc")

local filter_msg = function(pred)
  return vim.tbl_filter(pred, rpc.messages)
end

local initialized = false
local find_initialized = function()
  return initialized
    and vim.tbl_filter(function(msg)
      return msg.type == "notify" and msg.method == "initialized"
    end, rpc.messages)[1]
end

local eq = assert.are.same
describe("cody", function()
  before_each(function()
    require("sg.cody.rpc").start({}, function()
      initialized = true
    end)
  end)

  a.it("should have initialized", function()
    vim.wait(5000, find_initialized)

    local initialized = find_initialized()
    eq(initialized, { type = "notify", method = "initialized", params = {} })
  end)
end)

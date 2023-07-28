require("plenary.async").tests.add_to_env()

local async_system = require("sg.utils").async_system

local eq = assert.are.same

describe("compat", function()
  describe("vim.system", function()
    a.it("void functions can call wrapped functions", function()
      local obj = async_system({ "echo", "hello" }, { text = true })
      local result = obj.stdout
      eq(result, "hello\n")
    end)
  end)
end)

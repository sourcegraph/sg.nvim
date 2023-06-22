require("plenary.async").tests.add_to_env()

local system = require "sg.system"

local eq = assert.are.same

describe("compat", function()
  describe("vim.system", function()
    a.it("void functions can call wrapped functions", function()
      local obj = system.async({ "echo", "hello" }, { text = true })
      local result = obj.stdout
      eq(result, "hello\n")
    end)
  end)
end)

local utils = require "sg.utils"
local joinpath = utils.joinpath

local eq = assert.are.same

describe("compat", function()
  describe("vim.fs.joinpath", function()
    it("should join two paths", function()
      eq("foo/bar", joinpath("foo", "bar"))
    end)

    it("should join four paths", function()
      eq("foo/bar/baz/blah", joinpath("foo//", "bar", "baz/", "blah"))
    end)
  end)
end)

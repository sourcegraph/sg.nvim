local eq = assert.are.same

local bufread = require "sg.bufread"

describe("sg.bufread", function()
  describe("construct_path", function()
    it("should return with nothing substituted", function()
      eq("sg://URL@12345/-/main.go", bufread._construct_path("URL", "12345", "main.go"))
    end)

    it("should return with blob substituted", function()
      eq("sg://URL@12345/-/main.go", bufread._construct_path("URL", "12345", "blob/main.go"))
    end)

    it("should not put an at with no hash", function()
      eq("sg://URL/-/main.go", bufread._construct_path("URL", nil, "blob/main.go"))
    end)
  end)

  describe("deconstruct_path", function()
    it("should parse line numbers", function()
      local deconstructed =
        bufread._deconstruct_path "sg://github.com/sourcegraph/sourcegraph@main/-/blob/dev/sg/rfc.go?L29:2"

      eq("github.com/sourcegraph/sourcegraph", deconstructed.url)
      eq("main", deconstructed.commit)
      eq("dev/sg/rfc.go", deconstructed.filepath)
      eq(29, deconstructed.line)
      eq(2, deconstructed.col)
    end)
  end)
end)

local URI = require "sg.uri"

local eq = assert.are.same

local new_uri = function(c)
  return URI:new(c, {
    resolver = function(commit)
      return commit
    end,
  })
end

describe("URI", function()
  describe(":new()", function()
    describe("no commit", function()
      local cases = {
        "https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c",
        "https://sourcegraph.com/github.com/neovim/neovim/-/tree/src/nvim/autocmd.c",
        "sg://github.com/neovim/neovim/-/blob/src/nvim/autocmd.c",
        "sg://github.com/neovim/neovim/-/tree/src/nvim/autocmd.c",
        "sg://gh/neovim/neovim/-/blob/src/nvim/autocmd.c",
        "sg://gh/neovim/neovim/-/tree/src/nvim/autocmd.c",
        "sg://github.com/neovim/neovim/-/src/nvim/autocmd.c",
        "sg://gh/neovim/neovim/-/src/nvim/autocmd.c",
      }

      local expected = {
        remote = "github.com/neovim/neovim",
        filepath = "src/nvim/autocmd.c",
        commit = nil,
      }

      for _, c in ipairs(cases) do
        it(string.format("should handle case: '%s'", c), function()
          local uri = new_uri(c)
          for k, v in pairs(expected) do
            eq(v, uri[k], k)
          end
        end)
      end
    end)

    describe("with commit and args", function()
      local cases = {
        "https://sourcegraph.com/github.com/neovim/neovim@c818d8df349fff514eef8a529afe63e8102ca281/-/blob/src/nvim/autocmd.c",
        "sg://gh/neovim/neovim@c818d8df349fff514eef8a529afe63e8102ca281/-/blob/src/nvim/autocmd.c",
      }

      local expected = {
        remote = "github.com/neovim/neovim",
        filepath = "src/nvim/autocmd.c",
        commit = "c818d8df349fff514eef8a529afe63e8102ca281",
      }

      for _, c in ipairs(cases) do
        it(string.format("should handle case: '%s'", c), function()
          local uri = new_uri(c)
          for k, v in pairs(expected) do
            eq(v, uri[k], k)
          end
        end)
      end
    end)
  end)

  describe("construct_path", function()
    it("should return with nothing substituted", function()
      eq("sg://URL@12345/-/main.go", URI._construct_bufname("URL", "12345", "main.go"))
    end)

    it("should return with blob substituted", function()
      eq("sg://URL@12345/-/main.go", URI._construct_bufname("URL", "12345", "blob/main.go"))
    end)

    it("should not put an at with no hash", function()
      eq("sg://URL/-/main.go", URI._construct_bufname("URL", nil, "blob/main.go"))
    end)

    describe("github.com", function()
      it("should shorten github.com -> gh", function()
        eq(
          "sg://gh/neovim/neovim/-/src/nvim/autocmd.c",
          URI._construct_bufname("github.com/neovim/neovim", nil, "src/nvim/autocmd.c")
        )
      end)
    end)
  end)

  describe("deconstruct_path", function()
    it("should parse line numbers", function()
      local deconstructed = new_uri "sg://github.com/sourcegraph/sourcegraph@main/-/blob/dev/sg/rfc.go?L29:2"

      eq("github.com/sourcegraph/sourcegraph", deconstructed.remote)
      eq("main", deconstructed.commit)
      eq("dev/sg/rfc.go", deconstructed.filepath)
      eq(29, deconstructed.line)
      eq(2, deconstructed.col)

      eq("sg://gh/sourcegraph/sourcegraph@main/-/dev/sg/rfc.go", deconstructed:bufname())
    end)

    it("should handle paths with - in it", function()
      local deconstructed =
        new_uri "https://sourcegraph.com/github.com/sourcegraph/sourcegraph@main/-/blob/cmd/repo-updater/repoupdater/server.go"

      eq("github.com/sourcegraph/sourcegraph", deconstructed.remote)
      eq("main", deconstructed.commit)
      eq("cmd/repo-updater/repoupdater/server.go", deconstructed.filepath)
    end)

    it("should handle paths with no blob", function()
      local deconstructed =
        new_uri "https://sourcegraph.com/github.com/sourcegraph/sourcegraph@main/-/cmd/repo-updater/repoupdater/server.go"

      eq("github.com/sourcegraph/sourcegraph", deconstructed.remote)
      eq("main", deconstructed.commit)
      eq("cmd/repo-updater/repoupdater/server.go", deconstructed.filepath)
    end)

    it("should work here again", function()
      local deconstructed =
        new_uri "sg://github.com/sourcegraph/sourcegraph@61148fb0761d2b74badd3886d3221e817b4f1eb8/-/lib/codeintel/lsif/protocol/element.go"

      eq("lib/codeintel/lsif/protocol/element.go", deconstructed.filepath)
    end)
  end)
end)

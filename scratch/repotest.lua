local void = require("plenary.async").void
local rpc = R "sg.rpc"
local request = R "sg.request"
local context = R "sg.cody.context"

request.start(true)

local system = require "sg.system"

void(function()
  local bufnr = 269
  local repo = context.get_repo_id(bufnr)
  print("repo:", repo)
  local embeddings = rpc.embeddings(repo, "initialize tree-sitter languages for syntax highlighter")
  print("embeddings", vim.inspect(embeddings))
end)()

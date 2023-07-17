local void = require("plenary.async").void
local rpc = assert(require "sg.rpc", "loads rpc")

void(function()
  local err, data = rpc.embeddings("github.com/sourcegraph/sourcegraph", "syntax highlighting", { code = 2 })
  vim.print("err", err, "data", data)
end)()

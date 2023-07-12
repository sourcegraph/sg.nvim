-- local rpc = require "sg.rpc"
local void = require("plenary.async").void
local rpc = assert(require "sg.rpc", "loads rpc")

vim.wait(100)

vim.defer_fn(function()
  void(function()
    local err, data = rpc.embeddings("github.com/sourcegraph/sourcegraph", "syntax highlighting")
    vim.print("err", err, "data", data)
  end)()
end, 100)

-- || [sg] "{\"id\":2,\"method\":\"StreamingComplete\",\"message\":{\"message\":\"say 'hello'\"}}"

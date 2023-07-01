local void = require("plenary.async").void
-- local rpc = require "sg.rpc"
local rpc = require "sg.cody.rpc"

vim.defer_fn(function()
  void(function()
    local err, data = rpc.execute.list_recipes()
    vim.print("err", err, "data", data)
  end)()
end, 100)

-- || [sg] "{\"id\":2,\"method\":\"StreamingComplete\",\"message\":{\"message\":\"say 'hello'\"}}"

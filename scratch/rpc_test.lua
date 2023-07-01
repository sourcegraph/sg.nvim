local void = require("plenary.async").void
local rpc = require "sg.rpc"

vim.defer_fn(function()
  void(function()
    -- local recipes = rpc.list_recipes()
    -- vim.print(recipes)

    rpc.complete_stream "say 'hello'"
  end)()
end, 100)

-- || [sg] "{\"id\":2,\"method\":\"StreamingComplete\",\"message\":{\"message\":\"say 'hello'\"}}"

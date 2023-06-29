local void = require("plenary.async").void
local rpc = require "sg.rpc"

void(function()
  local recipes = rpc.list_recipes()
  vim.print(recipes)
end)()

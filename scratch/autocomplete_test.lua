local void = require("plenary.async").void
local rpc = assert(require "sg.cody.rpc", "rpc")

void(function()
  local filepath = vim.fn.expand "%:p"
  print("For... ", filepath)

  local err, data = rpc.autocomplete(filepath, { line = 9, character = 5 })
  print("Error:", err)
  print("Data:", vim.inspect(data))
end)()

local rpc = require "sg.cody.rpc"

print "executing..."

rpc.execute.list_recipes(function(err, recipes)
  print "got recipes"
  print("recipes -> ", vim.inspect(recipes))
end)

rpc.request("debugInfo", nil, function(err, result)
  print("got debug info", vim.inspect(result))
end)

vim.defer_fn(
  vim.schedule_wrap(function()
    vim.cmd [[Messages]]
  end),
  250
)

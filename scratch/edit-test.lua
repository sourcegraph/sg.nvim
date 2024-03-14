local rpc = require "sg.cody.rpc"

rpc.request("editCommands/test", nil, function(err, data)
  print "hello?"
  print(vim.inspect { err = err, data = data })
end)

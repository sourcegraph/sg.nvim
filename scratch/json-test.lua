local request = require "sg.request"
local rpc = require "sg.rpc"
assert(request)

vim.print(request)

rpc.get_info(vim.schedule_wrap(function(...)
  vim.print("INFO:", ...)
end))

print "requesting..."
request.request(
  "sourcegraph/get_user_info",
  { testing = true },
  vim.schedule_wrap(function(...)
    print("Hello?", vim.inspect { ... })
  end)
)

request.request(
  "sourcegraph/auth",
  { validate = false },

  vim.schedule_wrap(function(...)
    print("AUTH:: => ", vim.inspect { ... })
  end)
)

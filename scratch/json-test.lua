local request = require "sg.request"
assert(request)

vim.print(request)

print "requesting..."
request.request(
  "sourcegraph/get_user_info",
  { testing = true },
  vim.schedule_wrap(function(...)
    print("Hello?", vim.inspect { ... })
  end)
)

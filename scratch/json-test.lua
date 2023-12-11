local request = require "sg.request"

local rpc = require "sg.rpc"
assert(request)

-- local creds = require("sg.auth").get()
local set_auth = function()
  local creds = require("sg.auth").get()
  print(vim.inspect(creds))

  request.request(
    "sourcegraph/auth",
    creds,
    vim.schedule_wrap(function(err, data)
      if not err and data then
        require("sg.auth").set_auth(data)
      end
    end)
  )
end

set_auth()

-- rpc.get_info(vim.schedule_wrap(function(...)
--   vim.print("INFO:", ...)
-- end))
--
-- request.request(
--   "sourcegraph/get_user_info",
--   { testing = true },
--   vim.schedule_wrap(function(...)
--     print("Hello?", vim.inspect { ... })
--   end)
-- )

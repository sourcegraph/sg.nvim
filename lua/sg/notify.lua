local M = {}

M.NO_AUTH = function()
  vim.notify_once "[sg-cody] Unable to find valid authentication strategy. See `:help sg.auth` and then restart nvim"

  return false
end

M.NO_BUILD = function()
  vim.notify_once "[sg-cody] Unable to find cody binaries. You may not have run `:SourcegraphDownloadBinaries` or `:SourcegraphBuild` and then restart nvim"

  return false
end

M.INVALID_AUTH = function()
  vim.notify_once "[sg-cody] Invalid authentication. See `:help sg.auth`"
end

M.CODY_DISABLED = function()
  vim.notify_once "[sg-cody] Cody is disabled for your current instance. Please talk to site-admins or change authentication"
end

M.INVALID_NODE = function(reason)
  vim.notify_once(string.format("[sg-cody] Invalid node configuration: '%s'", reason))

  return nil
end

M.PRO_ENDING_SOON = function()
  local data = require("sg.private.data").get_cody_data()
  if data.ignored_notifications["cody.pro-trial-ending"] then
    return
  end

  vim.notify_once [[
[sg-cody] Your Cody Pro Trial is ending soon. 

Setup your payment information to continue using Cody Pro, you won't be charged until February 15.

For information to fix or ignore this warning see:
  :help cody.pro-trial-ending
]]
end

return M

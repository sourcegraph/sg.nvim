local M = {}

M.NO_AUTH = function()
  vim.notify_once "[sg-cody] Unable to find valid authentication strategy. See `:help sg.auth`"
end

M.INVALID_AUTH = function()
  vim.notify_once "[sg-cody] Invalid authentication. See `:help sg.auth`"
end

M.CODY_DISABLED = function()
  vim.notify_once "[sg-cody] Cody is disabled for your current instance. Please talk to site-admins or change authentication"
end

return M

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

M.INVALID_NODE = function(node_executable)
  vim.notify_once(
    string.format(
      "[sg-cody] Invalid node configuration ('%s'). Please check your node configuration and restart nvim.",
      node_executable
    )
  )

  return nil
end

return M

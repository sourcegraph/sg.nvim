local config = require "sg.config"

local M = {}

M.setup = function()
  -- TODO: Figure out how we might do this beforehand...
  M.get_client_id()

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("sourcegraph-attach", { clear = true }),
    pattern = "sg://*",
    callback = function()
      M.get_client_id()
    end,
  })
end

M.get_client_id = function()
  -- TODO: Restart the client if it is no longer active?
  if not M._client then
    local cmd = require("sg.private.find_artifact").find_rust_bin "sg-lsp"

    M._client = vim.lsp.start_client {
      cmd = { cmd },
      on_attach = function(...)
        return config.on_attach(...)
      end,
    }
  end

  return assert(M._client, "Must have a client started")
end

M.attach = function(bufnr)
  vim.lsp.buf_attach_client(bufnr or vim.api.nvim_get_current_buf(), M.get_client_id())
end

return M

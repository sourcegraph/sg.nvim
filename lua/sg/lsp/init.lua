local lib = require "sg.lib"

local config = {
  on_attach = function(_, bufnr)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
    vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = bufnr })
  end,
}

local M = {}

M.setup = function(opts)
  config.on_attach = opts.on_attach

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
    local root_dir = vim.fn.fnamemodify(require("plenary.debug_utils").sourced_filepath(), ":p:h:h:h:h")

    M._client = vim.lsp.start_client {
      cmd = { root_dir .. "/target/debug/sg-lsp" },
      on_attach = config.on_attach,
      -- handlers = handlers,
    }
  end

  return assert(M._client, "Must have a client started")
end

M.attach = function(bufnr)
  vim.lsp.buf_attach_client(bufnr or vim.api.nvim_get_current_buf(), M.get_client_id())
end

return M

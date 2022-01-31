local log = require "sg.log"
local rpc = require "sg.lsp.rpc"
local handlers = require "sg.lsp.handlers"

local M = {}

M.setup = function(opts)
  -- TODO: Need to figure out how to ask for the files concurrently.
  -- Otherwise it's gonna take forever to resolve all of them if you've
  -- got a lot of files.

  -- opts.handlers = vim.tbl_deep_extend("force", {
  --   ["textDocument/references"] = function()
  --     print "Yo, references"
  --   end,
  -- }, opts.handlers or {})

  -- require("lspconfig").sg.setup(opts)

  M.on_attach = opts.on_attach

  vim.cmd [[
    augroup SourcegraphLSP
      au!
      autocmd BufReadPost sg://* :lua require("sg.lsp").attach()
    augroup END
  ]]
end

M.start = function()
  if M._client then
    return
  end

  M._client = vim.lsp.start_client {
    cmd = { "/home/tjdevries/plugins/sg.nvim/target/debug/sg-lsp" },
    on_attach = M.on_attach,
    -- handlers = handlers,
  }
end

M.attach = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  M.start()
  vim.lsp.buf_attach_client(bufnr, M._client)
end

return M

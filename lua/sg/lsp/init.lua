local async = require "plenary.async"
local void = async.void

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

local preload_file = function(location)
  local async_edit = async.wrap(require("sg.bufread").edit, 3)
  -- sg://github.com/tjdevries/simple-ocaml@5d0a2/-/lib/simple.ml
  local bufnr = vim.fn.bufnr(location.uri)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(true, false)
    async_edit(bufnr, location.uri)
  end
end

M.get_client_id = function()
  if M._client then
    return M._client
  end

  -- TODO: Restart the client if it is no longer active?
  local cmd = require("sg.private.find_artifact").find_rust_bin "sg-lsp"
  if not cmd then
    return
  end

  local auth = require("sg.auth").get()
  if not auth then
    return
  end

  M._client = vim.lsp.start_client {
    name = "sourcegraph",
    cmd = { cmd },
    cmd_env = {
      SRC_ENDPOINT = auth.endpoint,
      SRC_ACCESS_TOKEN = auth.token,
    },
    handlers = {
      -- For definitions, we need to preload the buffers so that we don't
      -- have an error when we try to navigate synchronously to the location
      -- via the normal way LSPs navigate
      ["textDocument/definition"] = function(_, result, ctx, config_)
        void(function()
          if vim.tbl_islist(result) then
            for _, res in ipairs(result) do
              preload_file(res)
            end
          else
            preload_file(result)
          end

          vim.lsp.handlers["textDocument/definition"](_, result, ctx, config_)
        end)()
      end,
    },
    on_attach = function(...)
      return config.on_attach(...)
    end,
  }

  return assert(M._client, "Must have a client started")
end

M.attach = function(bufnr)
  local client_id = M.get_client_id()
  if client_id then
    vim.lsp.buf_attach_client(bufnr or vim.api.nvim_get_current_buf(), client_id)
  end
end

return M

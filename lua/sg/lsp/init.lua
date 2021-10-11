local log = require "sg.log"
local rpc = require "sg.lsp.rpc"
local handlers = require "sg.lsp.handlers"

-- Weird that they use "/" for requires... I do not like it.
local configs = require "lspconfig/configs"

configs.sg = {
  default_config = {
    -- cmd = { "nvim", "--headless", "-c", 'lua require("sg.lsp").start()' },
    -- cmd = { "cargo", "run", "--bin", "sg-lsp" },
    cmd = { "./target/debug/sg-lsp" },

    root_dir = function(fname)
      if not vim.startswith(fname, "sg://") then
        return nil
      end

      log.trace("Successfully connected to:", fname)
      return "/"
    end,

    -- log_level = vim.lsp.protocol.MessageType.Log,
  },
}

local M = {}

M.setup = function(opts)
  -- TODO: Need to figure out how to ask for the files concurrently.
  -- Otherwise it's gonna take forever to resolve all of them if you've
  -- got a lot of files.

  opts.handlers = vim.tbl_deep_extend("force", {
    ["textDocument/references"] = function(err, result, ctx, config)
      -- print(vim.inspect(result))

      print "Yo, references"
      for _, item in ipairs(result) do
        -- print(vim.inspect(result))
        -- local bufnr = vim.fn.bufadd(item.uri)
        -- vim.fn.bufload(bufnr)

        print(item.uri)
      end

      vim.lsp.handlers["textDocument/references"](err, result, ctx, config)
    end,
  }, opts.handlers or {})

  require("lspconfig").sg.setup(opts)
end

return M

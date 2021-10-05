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

  -- opts.handlers = vim.tbl_deep_extend("force", {
  --   ["textDocument/references"] = function()
  --     print "Yo, references"
  --   end,
  -- }, opts.handlers or {})

  require("lspconfig").sg.setup(opts)
end

return M

-- M.start = function()
--   local ok, msg = pcall(function()
--     log.info "[sg lsp] Started"

--     while not Shutdown do
--       -- header
--       local err, data = rpc.read_message()

--       if data == nil then
--         if err == "eof" then
--           return os.exit(1)
--         end
--         error(err)
--       elseif data.method then
--         -- request
--         if not handlers[data.method] then
--           log.info("confused by %t", data)
--           err = string.format("%q: Not found/NYI", tostring(data.method))
--           log.warn("%s", err)
--         else
--           local ok
--           ok, err = xpcall(function()
--             handlers[data.method](data.params, data.id)
--           end, debug.traceback)

--           if not ok then
--             log.warn("%s", tostring(err))
--           end
--         end
--       elseif data.result then
--         rpc.finish(data)
--       elseif data.error then
--         log.info("client error:%s", data.error.message)
--       end
--     end

--     os.exit(0)
--   end)

--   if not ok then
--     log.info("ERROR:", msg)
--   end
-- end

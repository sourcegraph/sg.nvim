local M = {}

M.setup = function(opts)
  require("sg.lsp").on_attach = opts.on_attach
end

return M

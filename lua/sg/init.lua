local data_file = vim.fs.joinpath(vim.fn.stdpath "data", "cody.json")

local M = {}

---@class CodyConfig
---@field tos_accepted boolean

local get_cody_data = function()
  local handle = io.open(data_file, "r")

  ---@type CodyConfig
  local cody_data = {
    tos_accepted = false,
  }

  if handle ~= nil then
    local contents = handle:read "*a"
    local ok, decoded = pcall(vim.json.decode, contents)
    if ok and decoded then
      cody_data = decoded
    end
  end

  return cody_data
end

local write_cody_data = function(cody_data)
  vim.notify("[cody] Writing data to:" .. data_file)
  vim.fn.writefile({ vim.json.encode(cody_data) }, data_file)
end

local accept_tos = function()
  local cody_data = get_cody_data()
  if not cody_data.tos_accepted then
    local choice = vim.fn.inputlist {
      "By using Cody, you agree to its license and privacy statement:"
        .. " https://about.sourcegraph.com/terms/cody-notice . Do you wish to proceed? Yes/No: ",
      "1. Yes",
      "2. No",
    }

    cody_data.tos_accepted = choice == 1
    write_cody_data(cody_data)
  end

  return cody_data.tos_accepted
end

M.setup = function(opts)
  accept_tos()
  require("sg.lsp").setup { on_attach = opts.on_attach }
end

M.accept_tos = accept_tos

return M

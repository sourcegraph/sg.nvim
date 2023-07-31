-- Force environment variables when loading the library
local creds = require("sg.auth").get() or {}
if not creds then
  require("sg.notify").NO_AUTH()
end

local original_endpoint = vim.env.SRC_ENDPOINT
local original_token = vim.env.SRC_ACCESS_TOKEN

vim.env.SRC_ENDPOINT = creds.endpoint
vim.env.SRC_ACCESS_TOKEN = creds.token

local lib = require("sg.private.find_artifact").find_rust_lib "libsg_nvim"

vim.env.SRC_ENDPOINT = original_endpoint
vim.env.SRC_ACCESS_TOKEN = original_token

return lib

-- Force environment variables when loading the library
vim.env.SRC_ACCESS_TOKEN = vim.env.SRC_ACCESS_TOKEN or require("sg.auth").token()
vim.env.SRC_ENDPOINT = vim.env.SRC_ENDPOINT or require("sg.auth").endpoint()

return require("sg.private.find_artifact").find_rust_lib "libsg_nvim"

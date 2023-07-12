local x = "textDocument/didOpen"
print(vim.json.encode(x))
print(vim.json.decode(vim.json.encode(x)))
print(vim.fn.json_encode(x))

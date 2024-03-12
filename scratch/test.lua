vim.api.nvim_create_autocmd("CursorMoved", {
  callback = function(arg)
    print(vim.inspect(arg))
    print(vim.inspect(vim.v.event))
    print(vim.inspect(vim.api.nvim_eval "v:"))
  end,
})

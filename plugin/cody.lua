local cody_commands = require "sg.cody.commands"

vim.api.nvim_create_user_command("CodyExplain", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  cody_commands.explain(bufnr, command.line1 - 1, command.line2)
end, { range = 2 })

vim.api.nvim_create_user_command("CodyChat", function(command)
  local name = nil
  if not vim.tbl_isempty(command.fargs) then
    name = table.concat(command.fargs, " ")
  end

  cody_commands.chat(name)
end, { nargs = "*" })

vim.api.nvim_create_user_command("CodyToggle", function(command)
  cody_commands.toggle()
end, {})

vim.api.nvim_create_user_command("CodyHistory", function()
  cody_commands.history()
end, {})

vim.api.nvim_create_user_command("CodyContext", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = command.line1 - 1
  local end_line = command.line2

  cody_commands.add_context(bufnr, start_line, end_line)
end, { range = 2 })

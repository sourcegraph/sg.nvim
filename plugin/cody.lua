---@tag cody.commands

---@brief [[
--- Default commands for interacting with Cody
---@brief ]]

---@config { ["module"] = "cody" }

local cody_commands = require "sg.cody.commands"

local M = {}

---@command CodyExplain [[
--- Explain how to use Cody.
---
--- Use from visual mode to pass the current selection
---@command ]]
vim.api.nvim_create_user_command("CodyExplain", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  cody_commands.explain(bufnr, command.line1 - 1, command.line2)
end, { range = 2 })

---@command CodyAsk [[
--- Ask a question about the current selection.
---
--- Use from visual mode to pass the current selection
---@command ]]
vim.api.nvim_create_user_command("CodyAsk", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  cody_commands.ask(bufnr, command.line1 - 1, command.line2, command.args)
end, { range = 2, nargs = 1 })

---@command :CodyChat {module} [[
--- State a new cody chat, with an optional {title}
---@command ]]
vim.api.nvim_create_user_command("CodyChat", function(command)
  local name = nil
  if not vim.tbl_isempty(command.fargs) then
    name = table.concat(command.fargs, " ")
  end

  cody_commands.chat(name)
end, { nargs = "*" })

---@command :CodyFloat [[
--- Ask Cody about the selected code. Cody responds in a floating window.
---@command ]]
vim.api.nvim_create_user_command("CodyFloat", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  cody_commands.float(bufnr, command.line1 - 1, command.line2, command.args)
end, { range = 2, nargs = 1 })
--
---@command :CodyToggleFloat [[
--- Hides/shows the Cody float window.
---@command ]]
vim.api.nvim_create_user_command("CodyToggleFloat", function(_)
  cody_commands.float_toggle()
end, {})

---@command CodyToggle [[
--- Toggles the current Cody Chat window.
---@command ]]
vim.api.nvim_create_user_command("CodyToggle", function(_)
  cody_commands.toggle()
end, {})

---@command CodyHistory [[
--- Select a previous chat from the current neovim session
---@command ]]
vim.api.nvim_create_user_command("CodyHistory", function()
  cody_commands.history()
end, {})

-- TODO: Decide if this makes sense to still be here after
-- using cody agent now.
vim.api.nvim_create_user_command("CodyContext", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = command.line1 - 1
  local end_line = command.line2

  cody_commands.add_context(bufnr, start_line, end_line)
end, { range = 2 })

return M

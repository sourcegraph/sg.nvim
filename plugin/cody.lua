---@tag cody.commands

---@brief [[
--- Default commands for interacting with Cody
---@brief ]]

---@config { ["module"] = "cody" }

local cody_commands = require "sg.cody.commands"
local config = require "sg.config"

local M = {}

M.tasks = {}

---@command :CodyAsk [[
--- Ask a question about the current selection.
---
--- Use from visual mode to pass the current selection
---@command ]]
vim.api.nvim_create_user_command("CodyAsk", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  cody_commands.ask(bufnr, command.line1 - 1, command.line2, command.args)
end, { range = 2, nargs = 1 })

-- TODO: This isn't ready yet, but we should explore how to expose this
-- ---@command CodyRecipes [[
-- --- Use cody recipes on a selection
-- ---@command ]]
-- vim.api.nvim_create_user_command("CodyRecipes", function(command)
--   local bufnr = vim.api.nvim_get_current_buf()
--   cody_commands.recipes(bufnr, command.line1 - 1, command.line2)
-- end, { range = 2 })

---@command :CodyChat {module} [[
--- State a new cody chat, with an optional {title}
---@command ]]
vim.api.nvim_create_user_command("CodyChat", function(command)
  -- TODO: This is not great... how to configure? Can at least
  -- pass default here.

  local name = nil
  if not vim.tbl_isempty(command.fargs) then
    name = table.concat(command.fargs, " ")
  end

  cody_commands.chat(config.default_layout, name)
end, { nargs = "*" })

---@command CodyToggle [[
--- Toggles the current Cody Chat window.
---@command ]]
vim.api.nvim_create_user_command("CodyToggle", function(args)
  local kind = args[1] or config.default_layout
  cody_commands.toggle(kind)
end, {
  nargs = "*",
})

---@command :CodyDo [[
---@deprecated
--- DEPRECATED. Use CodyTask.
---@command ]]
vim.api.nvim_create_user_command("CodyDo", function(_)
  error "CodyDo is deprecated. Use CodyTask instead."
end, { range = 2, nargs = 1 })

---@command :CodyTask {module} [[
--- Instruct Cody to perform a task on selected text.
---@command ]]
vim.api.nvim_create_user_command("CodyTask", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  local task = cody_commands.do_task(bufnr, command.line1 - 1, command.line2, command.args)
  table.insert(M.tasks, task)
  M.active_task_index = #M.tasks
end, { range = 2, nargs = 1 })

---@command :CodyTaskView [[
--- Opens the last active CodyTask.
---@command ]]
vim.api.nvim_create_user_command("CodyTaskView", function()
  if #M.tasks == 0 then
    print "No pending tasks"
    return
  end

  if #M.tasks < M.active_task_index then
    M.active_task_index = #M.tasks
  end

  if M.active_task_index > 0 then
    M.tasks[M.active_task_index].layout:show()
  end
end, {})

---@command :CodyTaskAccept [[
--- Accepts the current CodyTask, removing it from the pending tasks list and applying
--- it to the selection the task was performed on.
--- Can also be triggered by pressing <CR> while a task is open.
---@command ]]
vim.api.nvim_create_user_command("CodyTaskAccept", function()
  if #M.tasks == 0 then
    print "No pending tasks"
    return
  end

  if M.tasks[M.active_task_index] then
    M.tasks[M.active_task_index]:apply()
    M.tasks[M.active_task_index].layout:hide()
    table.remove(M.tasks, M.active_task_index)
  end
end, {})

---@command :CodyTaskPrev [[
--- Cycles to the previous CodyTask. Navigates to the appropriate buffer location.
---@command ]]
vim.api.nvim_create_user_command("CodyTaskPrev", function()
  if #M.tasks == 0 then
    print "No pending tasks"
    return
  end

  if M.tasks[M.active_task_index] then
    M.tasks[M.active_task_index].layout:hide()
  end
  M.active_task_index = M.active_task_index - 1
  if M.active_task_index < 1 then
    M.active_task_index = #M.tasks
  end
  M.tasks[M.active_task_index]:show()
end, {})

---@command :CodyTaskNext [[
--- Cycles to the next CodyTask. Navigates to the appropriate buffer location.
---@command ]]
vim.api.nvim_create_user_command("CodyTaskNext", function()
  if #M.tasks == 0 then
    print "No pending tasks"
    return
  end

  if M.tasks[M.active_task_index] then
    M.tasks[M.active_task_index].layout:hide()
  end
  M.active_task_index = M.active_task_index + 1
  if M.active_task_index > #M.tasks then
    M.active_task_index = 1
  end
  M.tasks[M.active_task_index]:show()
end, {})

---@command CodyHistory [[
--- Select a previous chat from the current neovim session
---@command ]]
vim.api.nvim_create_user_command("CodyHistory", function()
  cody_commands.history()
end, {})

return M

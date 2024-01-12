---@tag cody.commands

---@brief [[
--- Default commands for interacting with Cody
---@brief ]]

---@config { ["module"] = "cody" }

local cody_commands = require "sg.cody.commands"
local data = require "sg.private.data"

local accept_tos = function(opts)
  opts = opts or {}

  local cody_data = data.get_cody_data()
  if opts.accept_tos and not cody_data.tos_accepted then
    cody_data.tos_accepted = true
    data.write_cody_data(cody_data)
  end

  if not cody_data.tos_accepted then
    local choice = vim.fn.inputlist {
      "By using Cody, you agree to its license and privacy statement:"
        .. " https://about.sourcegraph.com/terms/cody-notice . Do you wish to proceed? Yes/No: ",
      "1. Yes",
      "2. No",
    }

    cody_data.tos_accepted = choice == 1
    data.write_cody_data(cody_data)
  end

  if not cody_data.user then
    cody_data.user = require("sg.utils").uuid()
    data.write_cody_data(cody_data)
  end

  return cody_data.tos_accepted
end

local M = {}

local commands = {}

---@command :CodyAsk [[
--- Ask a question about the current selection.
---
--- Use from visual mode to pass the current selection
---@command ]]
commands.CodyAsk = {
  function(command)
    if command.range == 0 then
      cody_commands.ask(command.args)
    else
      local bufnr = vim.api.nvim_get_current_buf()
      cody_commands.ask_range(bufnr, command.line1 - 1, command.line2, command.args)
    end
  end,
  { range = 2, nargs = 1 },
}

---@command :CodyExplain [[
--- Ask a question about the current selection.
---
--- Use from visual mode to pass the current selection
---@command ]]
commands.CodyExplain = {
  function(command)
    local proto = require "sg.cody.protocol"

    if command.range == 0 then
      cody_commands.ask(command.args)
    else
      local bufnr = vim.api.nvim_get_current_buf()
      require("sg.cody.rpc").notify(
        "textDocument/didChange",
        proto.get_text_document(bufnr, {
          content = true,
          selection = {
            start = {
              line = command.line1 - 1,
              character = 0,
            },
            ["end"] = {
              line = command.line2,
              character = 0,
            },
          },
        })
      )
      -- cody_commands.ask_range(bufnr, command.line1 - 1, command.line2, command.args)
      require("sg.cody.rpc").command.explain(function() end)
    end
  end,
  { range = 2 },
}

---@command :CodyChat{!} {title} [[
--- State a new cody chat, with an optional {title}
---
--- If {!} is passed, will reset the chat and start a new chat conversation.
---@command ]]
commands.CodyChat = {
  function(command)
    local name = nil
    if not vim.tbl_isempty(command.fargs) then
      name = table.concat(command.fargs, " ")
    end

    cody_commands.chat(name, { reset = command.bang })
  end,
  { nargs = "*", bang = true },
}

---@command :CodyToggle [[
--- Toggles the current Cody Chat window.
---@command ]]
commands.CodyToggle = {
  function(_)
    cody_commands.toggle()
  end,
  {},
}

---@command :CodyTask {task_description} [[
--- Instruct Cody to perform a task on selected text.
---@command ]]
commands.CodyTask = {
  function(command)
    local bufnr = vim.api.nvim_get_current_buf()
    local task = cody_commands.do_task(bufnr, command.line1 - 1, command.line2, command.args)
    table.insert(M.tasks, task)
    M.active_task_index = #M.tasks
  end,
  { range = 2, nargs = 1 },
}

---@command :CodyTaskView [[
--- Opens the last active CodyTask.
---@command ]]
commands.CodyTaskView = {
  function()
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
  end,
  {},
}

---@command :CodyTaskAccept [[
--- Accepts the current CodyTask, removing it from the pending tasks list and applying
--- it to the selection the task was performed on.
--- Can also be triggered by pressing <CR> while a task is open.
---@command ]]
commands.CodyTaskAccept = {
  function()
    if #M.tasks == 0 then
      print "No pending tasks"
      return
    end

    if M.tasks[M.active_task_index] then
      M.tasks[M.active_task_index]:apply()
      M.tasks[M.active_task_index].layout:hide()
      table.remove(M.tasks, M.active_task_index)
    end
  end,
  {},
}

local cody_task_move = function(direction)
  return function()
    if #M.tasks == 0 then
      print "No pending tasks"
      return
    end

    if M.tasks[M.active_task_index] then
      M.tasks[M.active_task_index].layout:hide()
    end
    M.active_task_index = M.active_task_index + direction

    if M.active_task_index < 1 then
      M.active_task_index = #M.tasks
    end
    if M.active_task_index > #M.tasks then
      M.active_task_index = 1
    end

    M.tasks[M.active_task_index]:show()
  end
end

---@command :CodyTaskPrev [[
--- Cycles to the previous CodyTask. Navigates to the appropriate buffer location.
---@command ]]
commands.CodyTaskPrev = { cody_task_move(-1), {} }

---@command :CodyTaskNext [[
--- Cycles to the next CodyTask. Navigates to the appropriate buffer location.
---@command ]]
commands.CodyTaskNext = { cody_task_move(1), {} }

---@command :CodyRestart [[
--- Restarts Cody and Sourcegraph, clearing all state.
---
--- Useful if you've re-authenticated or are testing your config
---@command ]]
commands.CodyRestart = {
  function()
    -- Restart cody client.
    require("sg.cody.rpc").start({ force = true }, function(client)
      -- Restart sg request after this one has started
      require("sg.request").start { force = true }

      if not client then
        vim.notify "Failed to load client"
      else
        vim.notify "Restarted cody client"
      end
    end)
  end,
  {},
}

commands.CodyDo = {
  function(_)
    error "CodyDo is deprecated. Use CodyTask instead."
  end,
  { range = 2, nargs = 1 },
}

local create_command = function(name)
  vim.api.nvim_create_user_command(name, unpack(commands[name]))
end

local delete_command = function(name)
  vim.api.nvim_del_user_command(name)
end

--- Setup Cody
---@param config sg.config
M.setup = function(config)
  if config.enable_cody then
    -- Don't set up if we are not enabled
    if not accept_tos(config) then
      return
    end

    for k, _ in pairs(commands) do
      create_command(k)
    end
  else
    for k, _ in pairs(commands) do
      delete_command(k)
    end
  end
end

M.tasks = {}

-- TODO: This isn't ready yet, but we should explore how to expose this
-- ---@command CodyRecipes [[
-- --- Use cody recipes on a selection
-- ---@command ]]
-- vim.api.nvim_create_user_command("CodyRecipes", function(command)
--   local bufnr = vim.api.nvim_get_current_buf()
--   cody_commands.recipes(bufnr, command.line1 - 1, command.line2)
-- end, { range = 2 })

return M

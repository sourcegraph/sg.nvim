---@tag cody.commands

---@brief [[
--- Default commands for interacting with Cody
---@brief ]]

---@config { ["module"] = "cody" }

local cody_commands = require "sg.cody.commands"

local M = {}

M.tasks = {}

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
  local name = nil
  if not vim.tbl_isempty(command.fargs) then
    name = table.concat(command.fargs, " ")
  end

  cody_commands.chat(name)
end, { nargs = "*" })

---@command :CodyFloat {module} [[
--- State a new cody chat in a floating window
---@command ]]
vim.api.nvim_create_user_command("CodyFloat", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  cody_commands.float(bufnr, command.line1 - 1, command.line2, command.args)
end, { range = 2, nargs = 1 })

---@command :CodyToggleFloat [[
--- Hides/shows the Cody float window.
---@command ]]
vim.api.nvim_create_user_command("CodyToggleFloat", function(_)
  cody_commands.float_toggle()
end, {})

---@command :CodyDo {module} [[
--- Instruct Cody to perform a task on selected text.
---@command ]]
vim.api.nvim_create_user_command("CodyDo", function(command)
  local bufnr = vim.api.nvim_get_current_buf()
  local task = cody_commands.do_task(bufnr, command.line1 - 1, command.line2, command.args)
  table.insert(M.tasks, task)
  M.active_task_index = #M.tasks
end, { range = 2, nargs = 1 })

vim.api.nvim_create_user_command("CodyTask", function(command)
  M.active_task_index = tonumber(command.args)

  if M.active_task_index > 0 then
    M.tasks[M.active_task_index].layout:show()
  end
end, { nargs = 1 })

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

vim.api.nvim_create_user_command("CodyTasks", function()
  local previewer = require("telescope.previewers.previewer"):new {
    setup = function() end,
    teardown = function() end,

    title = function(_)
      return "Cody Task Preview"
    end,

    dynamic_title = function()
      return "Cody Task Preview"
    end,

    preview_fn = function(_, entry, status)
      local bufnr = vim.api.nvim_win_get_buf(status.preview_win)

      entry.value.layout.state:render(bufnr, status.preview_win)
      vim.bo[bufnr].filetype = vim.bo[entry.value.bufnr].filetype
    end,

    send_input = function() end,
    scroll_fn = function() end,
  }
  -- our picker function: colors
  local colors = function(opts)
    opts = opts or {}
    require("telescope.pickers")
      .new(opts, {
        prompt_title = " Cody Tasks ",
        finder = require("telescope.finders").new_table {
          results = M.tasks,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.task,
              ordinal = entry.task,
            }
          end,
        },
        sorter = require("telescope.config").values.generic_sorter(opts),
        previewer = previewer,
        attach_mappings = function(prompt_bufnr, map)
          require("telescope.actions").select_default:replace(function()
            require("telescope.actions").close(prompt_bufnr)
            local selection = require("telescope.actions.state").get_selected_entry()
            selection.value:show()
          end)
          return true
        end,
      })
      :find()
  end

  -- to execute the function
  colors()
end, {})

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

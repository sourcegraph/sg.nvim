local M = {}

local tasks = {}

---@enum cody.CodyTaskState
local cody_task_state = {
  idle = 1,
  working = 2,
  inserting = 3,
  applying = 4,
  formatting = 5,
  applied = 6,
  finished = 7,
  error = 8,
  pending = 9,
}

---@class cody.CodyError
---@field message string
---@field cause? cody.CodyError
---@field stack? string

---@class cody.EditTask
---@field id string
---@field state cody.CodyTaskState
---@field error? cody.CodyError

---comment
---@param task_state any
M.did_change = function(task_state)
  print("editTaskState/didChange", vim.inspect(task_state))
end

-- editCommands/test

return M

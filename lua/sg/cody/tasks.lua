local CodyHover = require "sg.components.layout.hover"
local Speaker = require "sg.cody.speaker"
local Message = require "sg.cody.message"
local keymaps = require "sg.keymaps"

---@class CodyTask
---@field bufnr number
---@field task string
---@field marks_namespace string
---@field start_mark_id number
---@field end_mark_id number
---@field taskbufnr number buffer where the task result is stored
---@field layout CodyLayoutHover
---@field message_id number
local CodyTask = {}
CodyTask.__index = CodyTask

---@class CodyTaskOptions
---@field bufnr number
---@field task string
---@field start_line number
---@field end_line number

--- Create a new CodyTask
---@param opts CodyTaskOptions
---@return CodyTask
CodyTask.init = function(opts)
  -- A CodyTask should point to a very specific question and answer.
  local marks_namespace = vim.api.nvim_create_namespace("sg.nvim." .. opts.task)
  local start_mark_id = vim.api.nvim_buf_set_extmark(opts.bufnr, marks_namespace, opts.start_line, 0, {})
  local end_mark_id = vim.api.nvim_buf_set_extmark(opts.bufnr, marks_namespace, opts.end_line, 0, {})

  local layout = CodyHover.init {
    bufnr = opts.bufnr,
  }
  layout.state:append(Message.init(Speaker.user, vim.split(opts.task, "\n"), {}))

  local task = setmetatable({
    bufnr = opts.bufnr,
    marks_namespace = marks_namespace,
    start_mark_id = start_mark_id,
    end_mark_id = end_mark_id,
    task = opts.task,
    layout = layout,
  }, CodyTask)

  layout:run(function()
    layout:show()
    layout:hide()
    local id = layout:request_completion(true, vim.bo[opts.bufnr].filetype)
    task.message_id = id
    task:show()
  end)

  return task
end

function CodyTask:apply()
  local start_line = vim.api.nvim_buf_get_extmark_by_id(self.bufnr, self.marks_namespace, self.start_mark_id, {})[1]
  local end_line = vim.api.nvim_buf_get_extmark_by_id(self.bufnr, self.marks_namespace, self.end_mark_id, {})[1]
  vim.api.nvim_buf_set_lines(
    self.bufnr,
    start_line,
    end_line,
    false,
    vim.api.nvim_buf_get_lines(self.layout.history.bufnr, 0, -1, false)
  )
end

function CodyTask:show()
  vim.api.nvim_set_current_buf(self.bufnr)
  local start_line = vim.api.nvim_buf_get_extmark_by_id(self.bufnr, self.marks_namespace, self.start_mark_id, {})[1]
  vim.api.nvim_win_set_cursor(0, { start_line + 1, 0 })
  self.layout:show { start = self.message_id, finish = self.message_id }

  -- TODO: We should expose these as lua functions and use them here.
  -- I don't like making the command strings the primary way of interacting
  keymaps.map(self.layout.history.bufnr, "n", "<CR>", "", function()
    vim.cmd "CodyTaskAccept"
  end)
  keymaps.map(self.layout.history.bufnr, "n", "]", "", function()
    vim.cmd "CodyTaskNext"
  end)
  keymaps.map(self.layout.history.bufnr, "n", "[", "", function()
    vim.cmd "CodyTaskPrev"
  end)
end

return CodyTask

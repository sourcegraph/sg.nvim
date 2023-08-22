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
  local marks_namespace = vim.api.nvim_create_namespace("sg.nvim." .. opts.task)
  local start_mark_id = vim.api.nvim_buf_set_extmark(opts.bufnr, marks_namespace, opts.start_line, 0, {})
  local end_mark_id = vim.api.nvim_buf_set_extmark(opts.bufnr, marks_namespace, opts.end_line, 0, {})

  local layout = CodyHover.init {
    name = opts.task,
    bufnr = opts.bufnr,
    history = {
      filetype = vim.bo[opts.bufnr].filetype,
    },
  }
  layout:run(function()
    layout.state:append(Message.init(Speaker.user, vim.split(opts.task, "\n"), {}, { hidden = true }))
    layout:show()
    layout:request_completion(true)
  end)

  return setmetatable({
    bufnr = opts.bufnr,
    marks_namespace = marks_namespace,
    start_mark_id = start_mark_id,
    end_mark_id = end_mark_id,
    task = opts.task,
    layout = layout,
  }, CodyTask)
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
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  self.layout:show()

  keymaps.map(self.layout.history.bufnr, "n", "<CR>", "", function()
    vim.cmd "CodyTaskAccept"
  end)
end

return CodyTask

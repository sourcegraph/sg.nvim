local keymaps = require "sg.keymaps"

local CodyHover = require "sg.components.layout.hover"
local Speaker = require "sg.cody.speaker"
local Message = require "sg.cody.message"
local Mark = require "sg.mark"

local ns = vim.api.nvim_create_namespace "sg-nvim-tasks"

---@class CodyTask
---@field bufnr number
---@field task string
---@field mark CodyMarkWrapper
---@field taskbufnr number: buffer where the task result is stored
---@field layout CodyBaseLayout
---@field message_id number
local CodyTask = {}
CodyTask.__index = CodyTask

---@class CodyTaskOptions
---@field bufnr number
---@field task string
---@field start_row number
---@field end_row number
---@field layout CodyBaseLayout?

--- Create a new CodyTask
---@param opts CodyTaskOptions
---@return CodyTask
CodyTask.init = function(opts)
  -- A CodyTask should point to a very specific question and answer.
  local mark = Mark.init {
    ns = ns,
    bufnr = opts.bufnr,
    start_row = opts.start_row,
    start_col = 0,
    end_row = opts.end_row,
    end_col = 0,
  }

  ---@type CodyBaseLayout
  local layout = opts.layout
    or CodyHover.init {
      bufnr = opts.bufnr,
      code_only = true,
      code_ft = vim.bo[opts.bufnr].filetype,
    }
  layout.state:append(Message.init(Speaker.user, vim.split(opts.task, "\n"), {
    hidden = true,
  }))

  local task = setmetatable({
    bufnr = opts.bufnr,
    mark = mark,
    task = opts.task,
    layout = layout,
  }, CodyTask)

  local id = layout:request_completion(true, vim.bo[opts.bufnr].filetype)
  task.message_id = id
  task:show()

  return task
end

function CodyTask:apply()
  local start_row = self.mark:start_pos().row
  local end_row = self.mark:end_pos().row
  vim.api.nvim_buf_set_lines(
    self.bufnr,
    start_row,
    end_row,
    false,
    vim.api.nvim_buf_get_lines(self.layout.history.bufnr, 0, -1, false)
  )
end

function CodyTask:show()
  vim.api.nvim_set_current_buf(self.bufnr)
  local start_row = self.mark:start_pos().row
  vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })
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

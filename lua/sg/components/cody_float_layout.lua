local _ = require "sg.components.shared"
local keymaps = require "sg.keymaps"

local CodyHistory = require "sg.components.cody_history"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

local context = require "sg.cody.context"
local void = require("plenary.async").void
local util = require "sg.utils"

---@class CodyFloatLayoutOptions
---@field name string?
---@field history CodyHistoryOptions
---@field width number?
---@field state CodyState?
---@field bufnr number?
---@field start_line number?
---@field end_line number?

---@class CodyFloatLayout
---@field opts CodyFloatLayoutOptions
---@field state CodyState
---@field history CodyHistory
---@field active CodyFloatLayout?
local CodyFloatLayout = {}
CodyFloatLayout.__index = CodyFloatLayout

--- Create a new CodyFloatLayout
---@param opts CodyFloatLayoutOptions
---@return CodyFloatLayout
CodyFloatLayout.init = function(opts)
  opts.history = opts.history or {}

  -- TODO: Show how you can use this, and maybe add config to the commands to handle this as well.
  -- opts.history.split = "botright vnew"
  -- opts.prompt.split = "new | call nvim_win_set_height(0, 5)"

  local width = opts.width or 0.25
  opts.history.width = width

  opts.history.height = 30

  local cursor = vim.api.nvim_win_get_cursor(0)

  local line_number_width = 0
  if vim.wo.number or vim.wo.relativenumber then
    line_number_width = vim.wo.numberwidth + 1
  end
  opts.history.row = cursor[1]
  opts.history.col = cursor[2] + line_number_width

  ---@type CodyFloatLayout
  local self = {
    opts = opts,
    state = opts.state or State.init {
      name = opts.name,
    },
  }

  return setmetatable(self, CodyFloatLayout)
end

function CodyFloatLayout:render()
  self.state:render(self.history.bufnr, self.history.win)
end

local callback = function(noti)
  local active = CodyFloatLayout.active

  if active then
    active.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
    active:render()
  else
    local layout = CodyFloatLayout.init {}
    layout:mount()

    layout.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
    layout:render()
  end
end

function CodyFloatLayout:complete()
  self.state:complete(self.history.bufnr, self.history.win, callback)
end

function CodyFloatLayout:mount()
  -- TODO: We probably need to do something to make sure that
  -- we actually  need to reload these windows. I think this will
  -- get a little scuffed with your layouts if you keep unmounting, then
  -- remounting the windows
  if CodyFloatLayout.active then
    CodyFloatLayout.active:unmount()
  end

  self.history = CodyHistory.init(self.opts.history)
  self.history:mount()

  -- TODO: add ? as shortcut to display shortcuts haha

  keymaps.map(self.history.bufnr, "n", "<CR>", "[cody] confirm edit", function()
    vim.api.nvim_buf_set_lines(
      self.opts.bufnr,
      self.opts.start_line,
      self.opts.end_line,
      false,
      vim.api.nvim_buf_get_lines(self.history.bufnr, 0, -1, false)
    )
    self.history:hide()
  end)

  -- TODO: We'll add this back after thinking about it a bit more
  -- keymaps.map(self.prompt.bufnr, "i", "<M-CR>", function()
  --   self.prompt:on_submit { request_embeddings = true }
  -- end)

  keymaps.map(self.history.bufnr, "n", "<ESC>", "[cody] quit float layout", function()
    self.history:hide()
  end)

  CodyFloatLayout.active = self
  vim.api.nvim_set_current_win(self.history.win)
end

function CodyFloatLayout:show()
  self.history:mount()
  vim.api.nvim_set_current_win(self.history.win)
end

function CodyFloatLayout:hide()
  self.history:hide()
end

function CodyFloatLayout:unmount()
  self.history:unmount()

  CodyFloatLayout.active = nil
end

function CodyFloatLayout:run(f)
  void(f)()
end

return CodyFloatLayout

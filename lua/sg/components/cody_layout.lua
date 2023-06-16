local _ = require "sg.components.shared"

local cody_prompt = require "sg.components.cody_prompt"
local cody_history = require "sg.components.cody_history"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

local void = require("plenary.async").void

---@class CodyLayoutOptions
---@field prompt CodyPromptOptions
---@field history CodyHistoryOptions
---@field width number?

---@class CodyLayout
---@field opts CodyLayoutOptions
---@field state CodyState
---@field prompt CodyPrompt
---@field history CodyHistory
local CodyLayout = {}
CodyLayout.__index = CodyLayout

---comment
---@param opts CodyLayoutOptions
---@return CodyLayout
local function new(opts)
  opts.prompt = opts.prompt or {}
  opts.history = opts.history or {}

  local width = opts.width or 0.5
  opts.prompt.width = width
  opts.history.width = width

  opts.prompt.height = opts.prompt.height or 5

  local line_count = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus ~= 0 then
    line_count = line_count - 1
  end

  opts.history.height = line_count - opts.prompt.height - 2 - 2

  opts.history.row = 0
  opts.prompt.row = opts.history.row + opts.history.height + 2

  local col = vim.o.columns - opts.history.width
  opts.history.col = col
  opts.prompt.col = col

  ---@type CodyLayout
  local self = {
    opts = opts,
    state = State.init(),
  }

  local on_submit = opts.prompt.on_submit
  opts.prompt.on_submit = function(bufnr, text)
    if on_submit then
      on_submit(bufnr, text)
    end

    void(function()
      self.state:append(Message.init(Speaker.user, text))
      self:complete()
    end)()
  end

  local on_close = opts.prompt.on_close
  opts.prompt.on_close = function()
    if on_close then
      on_close()
    end

    self.history:unmount()
  end

  return setmetatable(self, CodyLayout)
end

function CodyLayout:complete()
  print "1"
  self.state:render(self.history.bufnr)
  print "2"
  self.state:complete(self.history.bufnr)
  print "3"

  vim.api.nvim_buf_set_lines(self.prompt.bufnr, 0, -1, false, {})
  print "4"
end

function CodyLayout:mount()
  self.history = cody_history(self.opts.history)
  self.history:mount()

  self.prompt = cody_prompt(self.opts.prompt)
  self.prompt:mount()
end

function CodyLayout:hide()
  self.history:hide()
  self.prompt:hide()
end

function CodyLayout:unmount()
  self.history:unmount()
  self.prompt:unmount()
end

function CodyLayout:run(f)
  void(f)()
end

return new

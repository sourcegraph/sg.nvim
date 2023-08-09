RELOAD "sg"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"

local keymaps = require "sg.keymaps"
local util = require "sg.utils"

local Base = require "sg.components.layout.base"
local State = require "sg.cody.state"

---@class CodyLayoutFloatOpts : CodyBaseLayoutOpts
---@field width number?
---@field state CodyState?
---@field on_submit function?

---@class CodyLayoutFloat : CodyBaseLayout
---@field opts CodyLayoutFloatOpts
---@field super CodyBaseLayout
local CodyFloat = setmetatable({}, Base)
CodyFloat.__index = CodyFloat

---comment
---@param opts CodyLayoutFloatOpts
---@return CodyLayoutFloat
function CodyFloat.init(opts)
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

  local on_close = opts.prompt.on_close
  opts.prompt.on_close = function()
    if on_close then
      on_close()
    end

    self:delete()
  end

  local object = Base.init(opts)
  object.super = Base
  return setmetatable(object, CodyFloat) --[[@as CodyLayoutFloat]]
end

function CodyFloat:set_keymaps()
  keymaps.map(self.prompt.bufnr, "n", "<CR>", "[cody] submit message", function()
    self.prompt:on_submit()
  end)

  keymaps.map(self.prompt.bufnr, "i", "<C-CR>", "[cody] submit message", function()
    print "MAP SUBMIT"
    self.prompt:on_submit()
  end)

  -- TODO: We'll add this back after thinking about it a bit more
  -- keymaps.map(self.prompt.bufnr, "i", "<M-CR>", function()
  --   self.prompt:on_submit { request_embeddings = true }
  -- end)

  keymaps.map(self.prompt.bufnr, "i", "<c-c>", "[cody] quit chat", function()
    self.prompt:on_close()
  end)

  keymaps.map(self.prompt.bufnr, "n", "<ESC>", "[cody] quit chat", function()
    self.prompt:hide()
    self.history:hide()
  end)

  local with_history = function(key, mapped)
    if not mapped then
      mapped = key
    end

    local desc = "[cody] execute '" .. key .. "' in history buffer"
    keymaps.map(self.prompt.bufnr, { "n", "i" }, key, desc, function()
      if vim.api.nvim_win_is_valid(self.history.win) then
        vim.api.nvim_win_call(self.history.win, function()
          util.execute_keystrokes(mapped)
        end)
      end
    end)
  end

  with_history "<c-f>"
  with_history "<c-b>"
  with_history "<c-e>"
  with_history "<c-y>"

  keymaps.map(self.prompt.bufnr, "n", "?", "[cody] show keymaps", function()
    keymaps.help(self.prompt.bufnr)
  end)
end

function CodyFloat:request_completion()
  self:render()
  vim.api.nvim_buf_set_lines(self.prompt.bufnr, 0, -1, false, {})

  self.state:complete(self.history.bufnr, self.history.win, function(noti)
    self.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
    self:render()
  end)
end

local x = CodyFloat.init {}
print(x:show())

return CodyFloat

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"

local shared = require "sg.components.shared"
local keymaps = require "sg.keymaps"
local util = require "sg.utils"

local Base = require "sg.components.layout.base"

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

  -- opts.prompt.history = function(history)
  -- end

  opts.history.open = function(history)
    history.bufnr, history.win = shared.create(history.bufnr, history.win, {
      relative = "editor",
      width = shared.calculate_width(opts.history.width),
      height = shared.calculate_height(opts.history.height),
      row = shared.calculate_row(opts.history.row),
      col = shared.calculate_col(opts.history.col),
      style = "minimal",
      border = "rounded",
      title = " Cody History ",
      title_pos = "center",
    })
  end

  opts.prompt.open = function(prompt)
    prompt.bufnr, prompt.win = shared.create(prompt.bufnr, prompt.win, {
      relative = "editor",
      width = shared.calculate_width(prompt.opts.width),
      height = shared.calculate_height(prompt.opts.height),
      row = shared.calculate_row(prompt.opts.row),
      col = shared.calculate_col(prompt.opts.col),
      style = "minimal",
      border = "rounded",
      title = " Cody Chat ",
      title_pos = "left",
    })
    vim.api.nvim_set_current_win(prompt.win)
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

---@return number
function CodyFloat:request_completion()
  self:render()
  vim.api.nvim_buf_set_lines(self.prompt.bufnr, 0, -1, false, {})

  local id = self.state:append(Message.init(Speaker.cody, { "Loading ..." }, {}))
  self.state:complete(self.history.bufnr, self.history.win, function(msg)
    self.state:update_message(id, Message.init(Speaker.cody, vim.split(msg.text, "\n"), {}))
    self:render()
  end)
  return id
end

return CodyFloat

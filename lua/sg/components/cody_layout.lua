local _ = require "sg.components.shared"
local keymaps = require "sg.keymaps"

local CodyPrompt = require "sg.components.cody_prompt"
local CodyHistory = require "sg.components.cody_history"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

local context = require "sg.cody.context"
local void = require("plenary.async").void
local util = require "sg.utils"

---@class CodyLayoutOptions
---@field name string?
---@field prompt CodyPromptOptions
---@field history CodyHistoryOptions
---@field width number?
---@field state CodyState?

---@class CodyLayout
---@field opts CodyLayoutOptions
---@field state CodyState
---@field prompt CodyPrompt
---@field history CodyHistory
---@field active CodyLayout?
local CodyLayout = {}
CodyLayout.__index = CodyLayout

--- Create a new CodyLayout
---@param opts CodyLayoutOptions
---@return CodyLayout
CodyLayout.init = function(opts)
  opts.prompt = opts.prompt or {}
  opts.history = opts.history or {}

  -- TODO: Show how you can use this, and maybe add config to the commands to handle this as well.
  -- opts.history.split = "botright vnew"
  -- opts.prompt.split = "new | call nvim_win_set_height(0, 5)"

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
    state = opts.state or State.init {
      name = opts.name,
    },
  }

  local on_submit = opts.prompt.on_submit

  --- On submit
  ---@param bufnr number
  ---@param text string[]
  ---@param submit_opts CodyPromptSubmitOptions
  opts.prompt.on_submit = function(bufnr, text, submit_opts)
    if on_submit then
      on_submit(bufnr, text)
    end

    void(function()
      if submit_opts.request_embeddings then
        context.add_context(bufnr, table.concat(text, "\n"), self.state)
      end

      self.state:append(Message.init(Speaker.user, text))
      self:complete()
    end)()
  end

  local on_close = opts.prompt.on_close
  opts.prompt.on_close = function()
    if on_close then
      on_close()
    end

    self:unmount()
  end

  return setmetatable(self, CodyLayout)
end

function CodyLayout:render()
  self.state:render(self.history.bufnr, self.history.win)
end

local callback = function(noti)
  local active = CodyLayout.active

  if active then
    active.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
    active:render()
  else
    local layout = CodyLayout.init {}
    layout:mount()

    layout.state:update_message(Message.init(Speaker.cody, vim.split(noti.text, "\n")))
    layout:render()
  end
end

function CodyLayout:complete()
  self:render()
  vim.api.nvim_buf_set_lines(self.prompt.bufnr, 0, -1, false, {})

  self.state:complete(self.history.bufnr, self.history.win, callback)
end

function CodyLayout:mount()
  -- TODO: We probably need to do something to make sure that
  -- we actually  need to reload these windows. I think this will
  -- get a little scuffed with your layouts if you keep unmounting, then
  -- remounting the windows
  if CodyLayout.active then
    CodyLayout.active:unmount()
  end

  self.history = CodyHistory.init(self.opts.history)
  self.history:mount()

  self.prompt = CodyPrompt.init(self.opts.prompt)
  self.prompt:mount()

  -- TODO: add ? as shortcut to display shortcuts haha

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
    self.prompt:on_close()
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

  self:render()

  CodyLayout.active = self
end

function CodyLayout:hide()
  self.history:hide()
  self.prompt:hide()
end

function CodyLayout:unmount()
  self.history:unmount()
  self.prompt:unmount()

  CodyLayout.active = nil
end

function CodyLayout:run(f)
  void(f)()
end

return CodyLayout

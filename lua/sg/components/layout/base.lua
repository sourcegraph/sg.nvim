local void = require("plenary.async").void

local CodyPrompt = require "sg.components.cody_prompt"
local CodyHistory = require "sg.components.cody_history"
local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

---@class CodyBaseLayoutOpts
---@field name string?
---@field state CodyState?
---@field prompt CodyPromptOpts?
---@field history CodyHistoryOpts

---@class CodyLayoutRenderOpts
---@field start number?
---@field finish number?

---@class CodyBaseLayout
---@field opts CodyBaseLayoutOpts
---@field state CodyState
---@field history CodyHistory
---@field prompt CodyPrompt?
---@field _active CodyBaseLayout?
local Base = {}
Base.__index = Base

--- Create a new base layout object
---@param opts CodyBaseLayoutOpts
---@return CodyBaseLayout
function Base.init(opts)
  return setmetatable({
    opts = opts,
    state = opts.state or State.last() or State.init {
      name = opts.name,
    },
  }, Base)
end

-- TODO: This doesn't really let us have multiple "active" windows...
-- I'll have to think about how to register this kind of idea.
--
-- Possibly an autocmd when entering a cody window that sets it to the
-- most recently active window?
function Base:get_active()
  return Base._active
end

function Base:set_active(obj)
  Base._active = obj
end

function Base:is_visible()
  return self.history and self.history.win and vim.api.nvim_win_is_valid(self.history.win)
end

function Base:toggle()
  local active = self:get_active()
  if not active then
    active = self.init {}
  end

  if not active:is_visible() then
    return active:show()
  else
    return active:hide()
  end
end

function Base:run(cb)
  void(cb)()
end

--- Asynchronously request a new message from a user.
---@param contents string[]
---@return nil: Does not return. Executes async
function Base:request_user_message(contents)
  self:run(function()
    self.state:append(Message.init(Speaker.user, contents))
    self:show()
    self:request_completion()
  end)
end

function Base:request_completion()
  error "Base:request_completion() is an abstract function"
end

function Base:create()
  local active = self:get_active()
  if active then
    active:delete()
    self:set_active(nil)
  end

  self.history = CodyHistory.init(self.opts.history)
  if self.opts.prompt then
    -- Override prompt options
    -- TODO: Do the other options as well
    local prompt_opts = assert(vim.deepcopy(self.opts.prompt))
    prompt_opts.on_submit = function(bufnr, text, submit_opts)
      void(function()
        if self.opts.prompt.on_submit then
          self.opts.prompt.on_submit(bufnr, text, submit_opts)
        end

        self:on_submit(bufnr, text, submit_opts)
      end)()
    end

    prompt_opts.on_close = function()
      if self.opts.prompt.on_close then
        self.opts.prompt.on_close()
      end

      self:delete()
    end

    self.prompt = CodyPrompt.init(prompt_opts)
  end

  self.created = true
end

--- Show the layout
---@param self CodyBaseLayout
---@param render_opts CodyLayoutRenderOpts?
function Base:show(render_opts)
  if not self.created then
    self:create()
  end

  self:set_active(self)

  self.history:show()
  if self.prompt then
    self.prompt:show()
    vim.api.nvim_set_current_win(self.prompt.win)
  end

  self:set_keymaps()
  self:render(render_opts)
end

--- Render the layout with the current state
---@param render_opts CodyLayoutRenderOpts?
function Base:render(render_opts)
  if self.created then
    self.state:render(self.history.bufnr, self.history.win, render_opts)
  end
end

function Base:hide()
  self.history:hide()
  if self.prompt then
    self.prompt:hide()
  end
end

function Base:delete()
  self.history:delete()
  if self.prompt then
    self.prompt:delete()
  end

  self.created = false
end

--- Callback for running on submit
function Base:on_submit(bufnr, text, submit_opts)
  self.state:append(Message.init(Speaker.user, text))
  self:request_completion()
end

function Base:set_keymaps() end

return Base

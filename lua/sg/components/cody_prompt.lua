local shared = require "sg.components.shared"

-- exiting insert mode places cursor one character backward,
-- so patch the cursor position to one character forward
-- when unmounting input.

---@class CodyPromptOptions
---@field height number|string
---@field width number|string
---@field row number|string
---@field col number|string
---@field on_submit function(bufnr: number, text: string[]): void
---@field on_change function?
---@field on_close function?

---@class CodyPrompt
---@field opts CodyPromptOptions
---@field popup_options table
---@field bufnr number
---@field win number
---@field mounted boolean
local CodyPrompt = {}
CodyPrompt.__index = CodyPrompt

--- Create a new CodyPrompt
---@param opts CodyPromptOptions
---@return CodyPrompt
function CodyPrompt.init(opts)
  local popup_options = {
    relative = "editor",
    width = shared.calculate_width(opts.width),
    height = shared.calculate_height(opts.height),
    row = shared.calculate_row(opts.row),
    col = shared.calculate_col(opts.col),
    style = "minimal",
    border = "rounded",
    title = " Cody Chat ",
    title_pos = "left",
  }

  return setmetatable({
    opts = opts,
    popup_options = popup_options,
    bufnr = -1,
    win = -1,
    mounted = false,
  }, CodyPrompt)
end

--- On submit
---@param self CodyPrompt
function CodyPrompt:on_submit()
  local value = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  if self.opts.on_submit then
    self.opts.on_submit(self.bufnr, value)
  end
end

--- On close
---@param self CodyPrompt
function CodyPrompt:on_close()
  self.bufnr = shared.buf_del(self.bufnr)

  vim.schedule(function()
    if vim.fn.mode() == "i" then
      vim.api.nvim_command "stopinsert"
    end

    if self.opts.on_close then
      self.opts.on_close()
    end
  end)
end

function CodyPrompt:mount()
  self.bufnr, self.win = shared.create(self.bufnr, self.win, self.popup_options)
  vim.api.nvim_set_current_win(self.win)

  vim.cmd [[startinsert!]]
end

function CodyPrompt:unmount()
  self:hide()

  self.bufnr = shared.buf_del(self.bufnr)
end

function CodyPrompt:hide()
  self.win = shared.win_del(self.win)
end

return CodyPrompt

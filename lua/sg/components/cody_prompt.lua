local shared = require "sg.components.shared"

---@class CodyPromptOpts
---@field open function(self): Create a buf, win pair
---@field split string?
---@field height number|string
---@field width number|string
---@field row number|string
---@field col number|string
---@field on_submit function(bufnr: number, text: string[]): void
---@field on_change function?
---@field on_close function?
---@field filetype string: The filetype to assign to the prompt buffer

---@class CodyPrompt
---@field open function(self): Open the window and bufnr, mutating self to store new win and bufnr
---@field opts CodyPromptOpts
---@field bufnr number
---@field win number
local CodyPrompt = {}
CodyPrompt.__index = CodyPrompt

--- Create a new CodyPrompt
---@param opts CodyPromptOpts
---@return CodyPrompt
function CodyPrompt.init(opts)
  return setmetatable({
    open = assert(opts.open, "Must have an `open` function for CodyPrompt"),
    opts = opts,
    bufnr = -1,
    win = -1,
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

function CodyPrompt:show()
  self:open()
  vim.api.nvim_set_current_win(self.win)
  vim.api.nvim_buf_set_name(self.bufnr, string.format("Cody Prompt (%d)", self.bufnr))

  vim.bo[self.bufnr].filetype = self.opts.filetype or "markdown.cody_prompt"
end

function CodyPrompt:delete()
  self:hide()

  self.bufnr = shared.buf_del(self.bufnr)
end

function CodyPrompt:hide()
  self.win = shared.win_del(self.win)
end

return CodyPrompt

local shared = require "sg.components.shared"

---@class CodyHistoryOptions
---@field height number|string
---@field width number|string
---@field row number|string
---@field col number|string

---@class CodyHistory
---@field opts CodyHistoryOptions
---@field popup_options table
---@field bufnr number
---@field win number
---@field mounted boolean
local CodyHistory = {}
CodyHistory.__index = CodyHistory

--- Create a new CodyHistory
---@param opts CodyHistoryOptions
---@return CodyHistory
function CodyHistory.init(opts)
  local popup_options = {
    relative = "editor",
    width = shared.calculate_width(opts.width),
    height = shared.calculate_height(opts.height),
    row = shared.calculate_row(opts.row),
    col = shared.calculate_col(opts.col),
    style = "minimal",
    border = "rounded",
    title = " Cody History ",
    title_pos = "center",
  }

  return setmetatable({
    opts = opts,
    popup_options = popup_options,
    bufnr = -1,
    win = -1,
    mounted = false,
  }, CodyHistory)
end

function CodyHistory:mount()
  self.bufnr, self.win = shared.create(self.bufnr, self.win, self.popup_options)

  vim.bo[self.bufnr].filetype = "markdown"
end

function CodyHistory:unmount()
  self:hide()
  self.bufnr = shared.buf_del(self.bufnr)
end

function CodyHistory:hide()
  self.win = shared.win_del(self.win)
end

return CodyHistory

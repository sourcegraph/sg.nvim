local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"

local shared = require "sg.components.shared"
local keymaps = require "sg.keymaps"
local util = require "sg.utils"

local Base = require "sg.components.layout.base"

---@class CodyLayoutHoverOpts : CodyBaseLayoutOpts
---@field width number?
---@field state CodyState?
---@field bufnr number?
---@field start_line number?
---@field end_line number?

---@class CodyLayoutHover : CodyBaseLayout
---@field opts CodyLayoutHoverOpts
---@field super CodyBaseLayout
local CodyHover = setmetatable({}, Base)
CodyHover.__index = CodyHover

---comment
---@param opts CodyLayoutHoverOpts
---@return CodyLayoutHover
function CodyHover.init(opts)
  opts.history = opts.history or {}

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

  opts.history.open = function(history)
    history.bufnr, history.win = shared.create(history.bufnr, history.win, {
      relative = "win",
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

  local object = Base.init(opts)
  object.super = Base
  return setmetatable(object, CodyHover) --[[@as CodyLayoutHover]]
end

--- Show current Hovered layout
---@param render_opts CodyLayoutRenderOpts?
function CodyHover:show(render_opts)
  self.super.show(self, render_opts)
  vim.api.nvim_set_current_win(self.history.win)
end

function CodyHover:set_keymaps()
  self.super.set_keymaps(self)

  local bufnr = self.history.bufnr

  keymaps.map(bufnr, "i", "<c-c>", "[cody] quit chat", function()
    self:hide()
  end)

  keymaps.map(bufnr, "n", "<ESC>", "[cody] quit chat", function()
    self:hide()
  end)

  local with_history = function(key, mapped)
    if not mapped then
      mapped = key
    end

    local desc = "[cody] execute '" .. key .. "' in history buffer"
    keymaps.map(bufnr, { "n", "i" }, key, desc, function()
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

  keymaps.map(bufnr, "n", "?", "[cody] show keymaps", function()
    keymaps.help(bufnr)
  end)
end

---Returns the id of the message where the completion will be.
---@param code_only boolean
---@param filetype string
---@return number
function CodyHover:request_completion(code_only, filetype)
  self:render()

  return self.state:complete(self.history.bufnr, self.history.win, function(id)
    return function(msg)
      if not msg then
        return
      end

      local lines = vim.split(msg.text or "", "\n")
      local render_lines = {}
      for _, line in ipairs(lines) do
        if code_only then
          if vim.trim(line) == "```" then
            require("sg.cody.rpc").message_callbacks[msg.data.id] = nil
            break
          end
        end
        table.insert(render_lines, line)
      end

      if code_only then
        render_lines = { "```" .. filetype, unpack(render_lines) }
        table.insert(render_lines, "```")
      end

      self.state:update_message(id, Message.init(Speaker.cody, render_lines, {}))
      self:render { start = id, finish = id }
    end
  end, { code_only = code_only })
end

return CodyHover

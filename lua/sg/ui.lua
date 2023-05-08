local Popup = require "nui.popup"
local is_type = require("nui.utils").is_type

-- exiting insert mode places cursor one character backward,
-- so patch the cursor position to one character forward
-- when unmounting input.
---@param target_cursor number[]
---@param force? boolean
local function patch_cursor_position(target_cursor, force)
  local cursor = vim.api.nvim_win_get_cursor(0)

  if target_cursor[2] == cursor[2] and force then
    -- didn't exit insert mode yet, but it's gonna
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + 1 })
  elseif target_cursor[2] - 1 == cursor[2] then
    -- already exited insert mode
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + 1 })
  end
end

---@alias sg_prompt_internal sg_prompt_internal|{ default_value: string, prompt: NuiText }

---@class SgPrompt: NuiInput
---@field private _ sg_prompt_internal
local SgPrompt = Popup:extend "NuiInput"

function SgPrompt:init(popup_options, options)
  popup_options.enter = true
  if not is_type("table", popup_options.size) then
    popup_options.size = {
      width = popup_options.size,
    }
  end

  SgPrompt.super.init(self, popup_options, options)

  local props = {}

  self.input_props = props
  self.input_props.on_submit = function()
    local value = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)

    -- Copied from original
    local target_cursor = vim.api.nvim_win_get_cursor(self._.position.win)
    local prompt_normal_mode = vim.fn.mode() == "n"
    vim.schedule(function()
      if prompt_normal_mode then
        -- NOTE: on prompt-buffer normal mode <CR> causes neovim to enter insert mode.
        --  ref: https://github.com/neovim/neovim/blob/d8f5f4d09078/src/nvim/normal.c#L5327-L5333
        vim.api.nvim_command "stopinsert"
      end

      patch_cursor_position(target_cursor, prompt_normal_mode)

      if options.on_submit then
        options.on_submit(value)
      end
    end)
  end

  props.on_close = function()
    local target_cursor = vim.api.nvim_win_get_cursor(self._.position.win)

    self:unmount()

    vim.schedule(function()
      if vim.fn.mode() == "i" then
        vim.api.nvim_command "stopinsert"
      end

      if not self._.disable_cursor_position_patch then
        patch_cursor_position(target_cursor)
      end

      if options.on_close then
        options.on_close()
      end
    end)
  end

  if options.on_change then
    props.on_change = function()
      local value_with_prompt = vim.api.nvim_buf_get_lines(self.bufnr, 0, 1, false)[1]
      local value = string.sub(value_with_prompt, self._.prompt:length() + 1)
      options.on_change(value)
    end
  end
end

function SgPrompt:mount(...)
  local props = self.input_props
  SgPrompt.super.mount(self)

  if props.on_change then
    vim.api.nvim_buf_attach(self.bufnr, false, {
      on_lines = props.on_change,
    })
  end

  vim.keymap.set("i", "<C-CR>", props.on_submit, { buffer = self.bufnr })
  vim.keymap.set("i", "<c-c>", props.on_close, { buffer = self.bufnr })

  vim.cmd [[startinsert!]]
end

return {
  SgPrompt = SgPrompt,
}

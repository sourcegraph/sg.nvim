local Prompt = require("sg.ui").SgPrompt
local Layout = require "nui.layout"
local Popup = require "nui.popup"

local event = require("nui.utils.autocmd").event

local M = {}

local get_chat = function(history)
  return Prompt({
    position = "50%",
    size = {
      width = "100%",
      height = "100%",
    },
    border = {
      style = "single",
      text = {
        top = "[Ask Cody]",
        top_align = "center",
      },
    },
    buf_options = {
      filetype = "markdown",
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    prompt = "> ",
    on_close = function()
      M.reset()
    end,
    on_submit = function(value)
      vim.api.nvim_buf_set_lines(history.bufnr, -1, -1, false, value)
    end,
  })
end

local get_history = function()
  return Popup { enter = false, border = "single", buf_options = { filetype = "markdown" } }
end

M.chat = function(opts)
  opts = opts or {}

  if M._history_window == nil then
    M._history_window = get_history()
  end

  if M._chat_window == nil then
    M._chat_window = get_chat(M._history_window)
  end

  if M._layout_window == nil then
    M._layout_window = Layout(
      {
        position = "100%",
        size = {
          width = 120,
          height = vim.o.lines - 2,
        },
        relative = "editor",
      },
      Layout.Box({
        Layout.Box(M._history_window, { size = "80%" }),
        Layout.Box(M._chat_window, { size = "20%" }),
      }, { dir = "col" })
    )

    M._layout_window:mount()
  else
    M._layout_window:show()
  end
end

M.hide = function()
  if M._layout_window then
    M._layout_window:hide()
  end
end

M.reset = function()
  M._history_window = nil
  M._chat_window = nil
  M._layout_window = nil
end

M.explain = function(line1, line2, prompt)
  prompt = prompt or vim.fn.input "prompt > "

  local p = "file://" .. vim.fn.expand "%:p"

  local filetype = vim.bo.filetype
  local contents = table.concat(vim.api.nvim_buf_get_lines(0, line1 - 1, line2 + 1, false), "\n")
  local snippet = string.format("%s:%s:%s\n```%s\n%s\n```\n\n%s", p, line1, line2, filetype, contents, prompt)

  M.chat()
  vim.api.nvim_buf_set_lines(M._history_window.bufnr, 0, -1, false, vim.split(snippet, "\n"))
  vim.api.nvim_buf_set_lines(M._history_window.bufnr, -1, -1, false, { "Loading ... " })
  local result = require("sg.lib").get_completions(snippet, nil)

  vim.api.nvim_buf_set_lines(M._history_window.bufnr, -1, -1, false, vim.split(vim.trim(result), "\n"))
end

vim.api.nvim_create_user_command("CodyExplain", function(command)
  M.explain(command.line1 - 1, command.line2 - 1, command.args)
end, { range = 2, nargs = 1 })

return M

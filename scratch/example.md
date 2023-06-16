```lua
local Prompt = require "sg.components.cody_prompt"

local void = require("plenary.async").void
local rpc = require "sg.rpc"

local M = {}

M.chat = function(opts)
  opts = opts or {}

  local history = get_history()
  local state = State.init(history.bufnr)
  local chat = get_chat(state)

  local layout = Layout(
    {
      position = "100%",
      size = {
        width = 120,
        height = vim.o.lines - 2,
      },
      relative = "editor",
    },
    Layout.Box({
      Layout.Box(history, { size = "80%" }),
      Layout.Box(chat, { size = "20%" }),
    }, { dir = "col" })
  )

  layout:mount()

  M._state = state
  M._history_window = history
  M._chat_window = chat
  M._layout_window = layout

  return state
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

  local state = M.chat()

  state:append(Message.init(Speaker.user, vim.split(snippet, "\n")))
  state:render()

  state:complete()
end

vim.api.nvim_create_user_command("CodyExplain", function(command)
  M.explain(command.line1 - 1, command.line2 - 1, command.args)
end, { range = 2, nargs = 1 })

return M
```

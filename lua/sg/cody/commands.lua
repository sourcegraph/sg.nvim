---@tag "cody.commands"
---@config { module = "sg.cody" }
---
local sg = require "sg"
local util = require "sg.utils"

local context = require "sg.cody.context"

local CodyLayout = require "sg.components.cody_layout"
local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

local commands = {}

--- Explain a piece of code
---@param bufnr number
---@param start_line number
---@param end_line number
commands.explain = function(bufnr, start_line, end_line)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local layout = CodyLayout.init {}

  local contents = vim.tbl_flatten {
    "Explain the following code for me:",
    "",
    util.format_code(bufnr, selection),
  }

  layout:run(function()
    context.add_context(bufnr, table.concat(selection, "\n"), layout.state)

    layout.state:append(Message.init(Speaker.user, contents))
    layout:mount()
    layout:complete()
  end)
end

--- Start a new CodyChat
---@param name string?
---@return CodyLayout
commands.chat = function(name)
  local layout = CodyLayout.init { name = name }
  layout:mount()

  return layout
end

--- Open a selection to get an existing Cody conversation
commands.history = function()
  local states = State.history()

  vim.ui.select(states, {
    prompt = "Cody History: ",
    format_item = function(state)
      return string.format("%s (%d)", state.name, #state.messages)
    end,
  }, function(state)
    vim.schedule(function()
      local layout = CodyLayout.init { state = state }
      layout:mount()
    end)
  end)
end

--- Add context to an existing state
---@param start_line any
---@param end_line any
---@param state CodyState?
commands.add_context = function(bufnr, start_line, end_line, state)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local content = vim.tbl_flatten {
    "Some additional context is:",
    util.format_code(bufnr, selection),
  }

  -- TODO: We should be re-rendering when we see this happen
  if not state then
    state = State.last()
  end
  state:append(Message.init(Speaker.user, content))
end

commands.toggle = function()
  if CodyLayout.active then
    CodyLayout.active:unmount()
  else
    local state = State.last()
    local layout = CodyLayout.init { state = state }
    layout:mount()
  end
end

-- Wrap all commands with making sure TOS is accepted
for key, value in pairs(commands) do
  commands[key] = function(...)
    sg.accept_tos()
    return value(...)
  end
end

return commands

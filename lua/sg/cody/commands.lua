local void = require("plenary.async").void

---@tag "cody.commands"
---@config { module = "sg.cody" }
---
local auth = require "sg.auth"
local sg = require "sg"
local util = require "sg.utils"

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
    -- context.add_context(bufnr, table.concat(selection, "\n"), layout.state)

    layout.state:append(Message.init(Speaker.user, contents))
    layout:mount()
    layout:complete()
  end)
end

--- Ask Cody about the selected code
---@param bufnr number
---@param start_line number
---@param end_line number
---@param message string
commands.ask = function(bufnr, start_line, end_line, message)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local layout = CodyLayout.init {}

  local contents = vim.tbl_flatten {
    message,
    "",
    util.format_code(bufnr, selection),
  }

  layout:run(function()
    -- context.add_context(bufnr, table.concat(selection, "\n"), layout.state)

    layout.state:append(Message.init(Speaker.user, contents))
    layout:mount()
    layout:complete()
  end)
end

--- Cancels any running Cody completions
commands.cancel = function()
  require("sg.cody.rpc").message_callbacks = {}
end

--- Start a new CodyChat
---@param name string?
---@return CodyLayout
commands.chat = function(name)
  local layout = CodyLayout.init { name = name }
  layout:mount()

  return layout
end

--- Ask Cody to preform a task on the selected code.
---@param bufnr number
---@param start_line number
---@param end_line number
---@param message string
commands.do_task = function(bufnr, start_line, end_line, message)
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local formatted = require("sg.utils").format_code(bufnr, selection)

  local prompt = message
  prompt = prompt .. "\nReply only with code, nothing else\n"
  prompt = prompt .. table.concat(formatted, "\n")

  local prefix = string.format("```%s", vim.bo[bufnr].filetype)

  void(function()
    print "Performing task..."
    local err, completed = require("sg.rpc").complete(prompt, { prefix = prefix, temperature = 0.1 })

    if err ~= nil or not completed then
      error("failed to execute instruction " .. message)
      return
    end

    local lines = {}
    for _, line in ipairs(vim.split(completed, "\n")) do
      -- This is to trim the rambling at the end that LLMs tend to do.
      -- TODO: This should be handled in the agent/LSP/whatever doing
      -- the GQL request, so that the response can be cut short
      -- without having to wait for the stream to complete. No sense
      -- waiting for text to complete that you're going to throw
      -- away.
      if line == "```" then
        break
      end
      table.insert(lines, line)
    end

    vim.api.nvim_buf_set_lines(0, start_line, end_line, false, lines)
  end)()
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

commands.recipes = function(bufnr, start_line, end_line)
  local selection = nil
  if start_line and end_line then
    selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  end

  local formatted = require("sg.utils").format_code(bufnr, selection)
  vim.print(formatted)

  local prompt =
    "You are an expert software developer and skilled communicator. Create a docstring for the following code. Make sure to document that functions purpose as well as any arguments."
  prompt = prompt .. "\n"
  prompt = prompt .. table.concat(formatted, "\n")
  prompt = prompt
    .. [[

Reply with JSON that meets the following specification:

interface Parameter {
  name: string
  type: string
  description: string
}

interface Docstring {
  function_description: string
  parameters: Parameter[]
}

If there are no parameters, just return an empty list.
]]

  local prefix = [[{"function_description":"]]

  void(function()
    print "Running completion..."
    local err, completed = require("sg.rpc").complete(prompt, { prefix = prefix, temperature = 0.1 })
    if err ~= nil then
      print "Failed to get completion"
      return
    end

    local ok, parsed = pcall(vim.json.decode, completed)
    if not ok then
      ok, parsed = pcall(vim.json.decode, prefix .. completed)
      if not ok then
        print "need to ask again... :'("
        print(completed)
        return
      end
    end

    if not parsed then
      print "did not send docstring"
      return
    end

    local lines = {}
    table.insert(lines, string.format("--- %s", parsed.function_description))
    table.insert(lines, "---")
    for _, param in ipairs(parsed.parameters) do
      table.insert(lines, string.format("---@param %s %s: %s", param.name, param.type, param.description))
    end

    vim.api.nvim_buf_set_lines(0, start_line, start_line, false, lines)
  end)()
end

-- Wrap all commands with making sure TOS is accepted
for key, value in pairs(commands) do
  commands[key] = function(...)
    sg.accept_tos()

    if not auth.valid() then
      vim.notify "You are not logged in to Sourcegraph. Use `:SourcegraphLogin` or `:help sg` to log in"
      return
    end

    return value(...)
  end
end

return commands

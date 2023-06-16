local cody_layout = require "sg.components.cody_layout"

local context = require "sg.cody.context"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

local format_code = function(bufnr, code)
  return { string.format("```%s", vim.bo[bufnr].filetype), code, "```" }
end

vim.api.nvim_create_user_command("CodyExplain", function(command)
  local p = "file://" .. vim.fn.expand "%:p"
  local bufnr = vim.api.nvim_get_current_buf()

  local start_line = command.line1 - 1
  local end_line = command.line2
  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local layout = cody_layout {}

  local contents = vim.tbl_flatten {
    "Explain the following code for me:",
    "",
    format_code(bufnr, selection),
  }

  layout:run(function()
    local repo = context.get_repo_id(bufnr)
    local embeddings = context.embeddings(repo, table.concat(selection, "\n"), "Code")

    if not vim.tbl_isempty(embeddings) then
      layout.state:append(Message.init(Speaker.user, { "Here is some context" }, { hidden = true }))

      for _, embed in ipairs(embeddings) do
        layout.state:append(Message.init(Speaker.user, vim.split(embed.content, "\n"), { hidden = true }))
      end
    end

    layout.state:append(Message.init(Speaker.user, contents))
    layout:mount()
    layout:complete()
  end)
end, { range = 2 })

vim.api.nvim_create_user_command("CodyChat", function(command)
  local name = nil
  if not vim.tbl_isempty(command.fargs) then
    name = table.concat(command.fargs, " ")
  end

  local layout = cody_layout { name = name }
  layout:mount()
end, { nargs = "*" })

vim.api.nvim_create_user_command("CodyHistory", function()
  local states = State.history()

  vim.ui.select(states, {
    prompt = "Cody History: ",
    format_item = function(state)
      return string.format("%s (%d)", state.name, #state.messages)
    end,
  }, function(state)
    vim.schedule(function()
      local layout = cody_layout { state = state }
      layout:mount()
    end)
  end)
end, {})

vim.api.nvim_create_user_command("CodyContext", function(command)
  local bufnr = vim.api.nvim_get_current_buf()

  local start_line = command.line1 - 1
  local end_line = command.line2

  local selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local content = vim.tbl_flatten { "Some additional context is:", format_code(bufnr, selection) }

  -- TODO: We should be re-rendering when we see this happen
  local state = State.last()
  state:append(Message.init(Speaker.user, content))
end, { range = 2 })

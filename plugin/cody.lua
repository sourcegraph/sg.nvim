local cody_layout = require "sg.components.cody_layout"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"

vim.api.nvim_create_user_command("SgCodyExplain", function(command)
  local p = "file://" .. vim.fn.expand "%:p"
  local bufnr = vim.api.nvim_get_current_buf()

  local start_line = command.line1 - 1
  local end_line = command.line2

  local layout = cody_layout {}

  local contents = { "Explain the following code for me:", "", string.format("```%s", vim.bo[bufnr].filetype) }
  vim.list_extend(contents, vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false))
  table.insert(contents, "```")

  layout:run(function()
    layout.state:append(Message.init(Speaker.user, contents))
    layout:mount()
    layout:complete()
  end)
end, { range = 2 })

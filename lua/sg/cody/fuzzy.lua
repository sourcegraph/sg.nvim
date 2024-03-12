local State = require "sg.cody.state"

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local Previewer = require "telescope.previewers.previewer"

local M = {}

--- Fuzzy find the messages
---@param state cody.State
M.messages = function(state)
  local previewer = Previewer:new {
    setup = function() end,
    teardown = function() end,

    title = function(_)
      return "Cody Message Preview"
    end,

    dynamic_title = function()
      return "Cody Message Preview"
    end,

    --- Preview function for telescope
    ---@param entry { value: CodyMessage }
    ---@param status any
    preview_fn = function(_, entry, status)
      local bufnr = vim.api.nvim_win_get_buf(status.preview_win)
      -- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(vim.inspect(entry.value), "\n"))
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, entry.value.msg)
    end,

    send_input = function() end,
    scroll_fn = function() end,
  }

  pickers
    .new({}, {
      prompt_title = "Cody Messages",
      finder = finders.new_table {
        results = state.messages,

        --- Create an entry
        ---@param entry CodyMessage
        ---@return table
        entry_maker = function(entry)
          local hidden = entry.hidden and "(hidden) " or ""

          -- Do something with the entry
          return {
            value = entry,
            display = string.format("%s%s", hidden, entry.msg[1]),
            ordinal = table.concat(entry.msg),
          }
        end,
      },
      previewer = previewer,
    })
    :find()
end

M.messages(State.last())

return M

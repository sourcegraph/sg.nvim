local CodySpeaker = require("sg.types").CodySpeaker
local Message = require "sg.cody.message"

---@class CodyTask
---@field bufnr number: buffer where the task was created
---@field task_bufnr number: buffer where the task result is stored
---@field task string: Request from the user
---@field mark CodyMarkWrapper
---@field layout CodyBaseLayout
---@field message_id number
local CodyTask = {}
CodyTask.__index = CodyTask

---@class CodyTaskOptions
---@field bufnr number: Original bufnr where the task was created
---@field task string
---@field start_row number
---@field end_row number
---@field layout CodyBaseLayout?

--- Create a new CodyTask
---@param opts CodyTaskOptions
CodyTask.init = function(opts)
  assert(opts.bufnr, "bufnr is required")

  local chat = require "sg.cody.rpc.chat"
  chat.new({
    interval = 0,
    window_type = "hover",
    window_opts = nil,
  }, function(_, id)
    local message = Message.init(CodySpeaker.human, opts.task, {
      hidden = true,
    })

    chat.submit_message(id, message:to_submit_message(), function()
      local task = chat.get_chat(id)
      if not task then
        return
      end

      local bufnr = task.windows.history_bufnr
      vim.keymap.set("n", "<CR>", function()
        local text = task.transcript:last_message():text()
        local lines = vim.split(vim.trim(text), "\n")
        local to_insert = {}

        local adding = false
        for _, line in ipairs(lines) do
          if adding and vim.startswith(line, "```") then
            break
          end

          if not adding then
            adding = vim.startswith(line, "```")
          else
            table.insert(to_insert, line)
          end
        end

        vim.api.nvim_buf_set_lines(opts.bufnr, opts.start_row, opts.end_row, false, to_insert)

        -- Attempt to indent this code
        vim.cmd(string.format("%s,%snorm! ==", opts.start_row, opts.end_row))

        -- Closes the task
        task:close()
      end, { buffer = bufnr })
    end)
  end)
end

return CodyTask

---@tag cody.coc
---@brief [[
--- Completion source for coc.nvim
---
--- To enable, you need to install coc.nvim.
---
--- At this time, it's not published to npm, but you can load the
--- plugin by adding `npm run build` to your installattion.
---
--- For example, if you're using Plug, you can do:
---
--- <code=vim>
---     Plug 'sourcegraph/sg.nvim', { 'do': 'nvim -l build/init.lua --install-coc-nvim' }
--- </code>
---
---
---@brief ]]
local config = require "sg.config"

local M = {}

local callback = vim.fn["sg#execute_callback"]

M.request = function()
  -- Delay loading until first complete, this makes sure that
  -- we can handle auth and everything beforehand
  local commands = require "sg.cody.commands"
  local document = require("sg.cody.protocol").document

  -- Don't trigger completions on useless buffers.
  -- This messes up the state of the agent.
  local bufnr = vim.api.nvim_get_current_buf()
  if not document.is_useful(bufnr) then
    callback {}
    return
  end

  -- Don't trigger completions when cody is disabled or if we have invalid auth
  if not config.enable_cody then
    callback {}
    return
  end

  if not require("sg.auth").get() then
    callback {}
    return
  end

  if not require("sg.cody.rpc").client then
    callback {}
    return
  end

  commands.autocomplete(nil, function(err, data)
    if err then
      if require("sg.ratelimit").is_ratelimit_err(err) then
        require("sg.ratelimit").notify_ratelimit "autocomplete"
        return
      end

      return
    end

    local items = {}
    for _, item in ipairs(data.items) do
      local trimmed = vim.trim(item.insertText)

      ---@type lsp.CompletionItem
      local completion_item = {
        filterText = trimmed,
        detail = trimmed,
        label = trimmed,

        -- Attempt to adjust indentation
        insertTextMode = 2,

        -- TODO: Should the range always be the entire line?...
        textEdit = {
          newText = item.insertText,
          range = item.range,
        },

        -- Store completeion ID for later
        data = {
          id = item.id,
        },
      }

      -- table.insert(items, trimmed)
      table.insert(items, completion_item)
    end

    callback(items)
  end)
end

return M

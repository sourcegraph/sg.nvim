---@tag cody.complete
---@brief [[
--- Completion source for nvim-cmp.
---
--- To enable, add `"cody"` to your nvim-cmp sources.
---
--- Optionally, you can trigger Cody Completions manually by doing:
---
--- <code=lua>
---   require("cmp").setup {
---     mapping = {
---       ...,
---       -- Manually trigger cody completions
---       ["<c-a>"] = cmp.mapping.complete {
---         config = {
---           sources = {
---             { name = "cody" },
---           },
---         },
---       },
---     },
---   }
--- </code>
---
--- You can add formatting via the `formatting` field in nvim-cmp. For example,
--- here's how you could configure if you're using `lspkind`:
---
--- <code=lua>
---   require('cmp').setup {
---     ...,
---     formatting = {
---       format = lspkind.cmp_format {
---         with_text = true,
---         menu = {
---           nvim_lsp = "[LSP]",
---           ...,
---           cody = "[cody]",
---         },
---       },
---     }
---   }
--- </code>
---
--- See |cmp-config.sources| for more information
---
---
---@brief ]]

local cmp = require "cmp"
local cmp_types = require "cmp.types.lsp"

local commands = require "sg.cody.commands"
local document = require "sg.document"

local M = {}

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "@", ".", "(", "{", " " }
end

source.get_keyword_pattern = function()
  -- Add dot to existing keyword characters (\k).
  return [[\%(\k\|\.\)\+]]
end

--- Completion source
---@param self table
---@param params cmp.SourceCompletionApiParams
---@param callback function(response: lsp.CompletionResponse)
source.complete = function(self, params, callback)
  _ = self
  _ = params

  -- Don't trigger completions on useless buffers.
  -- This messes up the state of the agent.
  local bufnr = vim.api.nvim_get_current_buf()
  if not document.is_useful(bufnr) then
    return
  end

  commands.autocomplete(nil, function(data)
    local items = {}
    for _, item in ipairs(data.items) do
      local trimmed = vim.trim(item.insertText)

      ---@type lsp.CompletionItem
      local completion_item = {
        filterText = trimmed,
        detail = trimmed,
        label = trimmed,

        -- Mark as snippet, not text.
        kind = cmp_types.CompletionItemKind.Snippet,

        -- Attempt to adjust indentation
        insertTextMode = cmp_types.InsertTextMode.AdjustIndentation,

        -- TODO: Should the range always be the entire line?...
        textEdit = {
          newText = item.insertText,
          range = item.range,
        },
      }

      table.insert(items, completion_item)
    end

    callback {
      items = items,
      isIncomplete = false,
    }
  end)
end

cmp.register_source("cody", source.new())

return M

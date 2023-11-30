---@tag cody.complete
---@brief [[
--- Completion source for nvim-cmp.
---
--- To enable, add `"cody"` to your nvim-cmp sources.
---
--- For example:
---
--- <code=lua>
---     require("cmp").setup {
---       ...,
---       sources = cmp.config.sources({
---         { name = "cody" },
---         { name = "nvim_lsp" },
---       },
---       ...
---     }
--- </code>
---
--- Cody items are highlighted with the `CmpItemKindCody` highlight group.
--- You can override the default color using |:highlight|
---
--- <code=lua>
---     vim.api.nvim_set_hl(0, "CmpItemKindCody", { fg = "Red" })
--- </code>
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
---@brief ]]

local cmp = require "cmp"
local cmp_types = require "cmp.types.lsp"

local commands = require "sg.cody.commands"
local document = require "sg.document"

local M = {}

local source = {}

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
function source:complete(params, callback)
  _ = self
  _ = params

  -- Don't trigger completions on useless buffers.
  -- This messes up the state of the agent.
  local bufnr = vim.api.nvim_get_current_buf()
  if not document.is_useful(bufnr) then
    return
  end

  -- Don't trigger completions when cody is disabled or if we have invalid auth
  if not require("sg.config").enable_cody or not require("sg.auth").valid { cached = true } then
    callback { items = {}, isIncomplete = false }
    return
  end

  commands.autocomplete(nil, function(err, data)
    if err then
      if require("sg.ratelimit").is_ratelimit_err(err) then
        return
      end

      -- TODO: Might want to do something else here?...
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

        cmp = {
          kind_hl_group = "CmpItemKindCody",
          kind_text = "Cody",
        },

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

cmp.register_source("cody", source)

return M

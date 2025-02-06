---@tag cody.complete
---@brief [[
--- Completion source for blink.cmp.
---
--- To enable, add the Cody source to your blink.cmp configuration:
--- <code=lua>
---     require("blink.cmp").setup {
---       sources = {
---         default = { 'lsp', 'path', 'snippets', 'buffer', 'cody' },
---         cody = {
---           name = "cody",
---           module = "sg.extensions.blink",
---           async = true,
---           transform_items = function(_, items)
---             local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
---             local kind_idx = #CompletionItemKind + 1
---             CompletionItemKind[kind_idx] = "Cody"
---             for _, item in ipairs(items) do
---               item.kind = kind_idx
---             end
---             return items
---           end,
---         }
---       },
---     }
--- </code>
---@brief ]]
---@module 'blink.cmp'

local config = require "sg.config"
local log = require "sg.log"

--- @type blink.cmp.Source
local M = {}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:enabled()
  local document = require("sg.cody.protocol").document

  -- Don't trigger completions on useless buffers
  -- This messes up the state of the agent.
  local bufnr = vim.api.nvim_get_current_buf()
  if not document.is_useful(bufnr) then
    log.trace "  skipping blink complete. not useful"
    return false
  end

  -- Don't trigger completions when cody is disabled or if we have invalid auth
  if not config.enable_cody then
    log.trace "  skipping blink complete. not enabled"
    return false
  end

  if not require("sg.auth").get() then
    log.trace "  skipping blink complete. not authed"
    return false
  end

  if not require("sg.cody.rpc").client then
    log.trace "  skipping blink complete. no client started"
    return false
  end

  return true
end

function M:get_trigger_characters()
  return { "@", ".", "(", "{", " " }
end

function M:get_completions(context, callback)
  log.trace "entering nvim-cmp complete"

  local commands = require "sg.cody.commands"

  commands.autocomplete(nil, function(err, data)
    if err then
      if require("sg.ratelimit").is_ratelimit_err(err) then
        require("sg.ratelimit").notify_ratelimit "autocomplete"
        return callback {}
      end

      -- TODO: Might want to do something else here?...
      log.debug("Failed to do autocomplete: ", err)
      return callback {}
    end

    local items = {} ---@type blink.cmp.CompletionItem[]
    for _, item in ipairs(data.items) do
      local trimmed = vim.trim(item.insertText)
      local completion_item = {
        filterText = trimmed,
        label = trimmed,
        detail = trimmed,

        kind = require("blink.cmp.types").CompletionItemKind.Text,

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
      table.insert(items, completion_item)
    end

    callback {
      items = items,
      isIncomplete = false,
    }
  end)
end

local is_valid_item = function(item)
  return config.enable_cody and vim.tbl_get(item, "data", "id")
end

function M:resolve(item, callback)
  if is_valid_item(item) then
    require("sg.cody.rpc").execute.autocomplete_suggested(item.data.id)
  end

  callback(item)
end

function M:execute(context, item, callback)
  if is_valid_item(item) then
    require("sg.cody.rpc").execute.autocomplete_accepted(item.data.id)
  end

  callback(item)
end

return M

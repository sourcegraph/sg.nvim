---@module 'blink.cmp'

local config = require "sg.config"
local log = require "sg.log"

--- @type blink.cmp.Source
local M = {}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:get_trigger_characters()
  return { "@", ".", "(", "{", " " }
end

function M:get_completions(context, callback)
  log.trace "entering nvim-cmp complete"

  local commands = require "sg.cody.commands"
  local document = require("sg.cody.protocol").document

  -- Don't trigger completions on useless buffers
  -- This messes up the state of the agent.
  local bufnr = vim.api.nvim_get_current_buf()
  if not document.is_useful(bufnr) then
    log.trace "  skipping blink complete. not useful"
    return callback {}
  end

  -- Don't trigger completions when cody is disabled or if we have invalid auth
  if not config.enable_cody then
    log.trace "  skipping blink complete. not enabled"
    return callback {}
  end

  if not require("sg.auth").get() then
    log.trace "  skipping blink complete. not authed"
    return callback {}
  end

  if not require("sg.cody.rpc").client then
    log.trace "  skipping blink complete. no client started"
    return callback {}
  end

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

    callback(items)
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

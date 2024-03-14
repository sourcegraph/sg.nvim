---@tag cody.builtin_complete

---@brief [[
--- Builtin Completion options for using Cody without any external
--- completion plugins.
---@brief ]]

local config = require "sg.config"
local log = require "sg.log"

local M = {}

M.complete = function(callback)
  -- Delay loading until first complete, this makes sure that
  -- we can handle auth and everything beforehand
  local commands = require "sg.cody.commands"
  local document = require("sg.cody.protocol").document

  -- Don't trigger completions on useless buffers.
  -- This messes up the state of the agent.
  local bufnr = vim.api.nvim_get_current_buf()
  if not document.is_useful(bufnr) then
    log.trace "  skipping cody complete. not useful"
    return
  end

  -- Don't trigger completions when cody is disabled or if we have invalid auth
  if not config.enable_cody then
    log.trace "  skipping cody complete. not enabled"
    callback {}
    return
  end

  if not require("sg.auth").get() then
    log.trace "  skipping cody complete. not authed"
    callback {}
    return
  end

  if not require("sg.cody.rpc").client then
    log.trace "  skipping nvim-cmp complete. no client started"
    callback {}
    return
  end

  commands.autocomplete(nil, function(err, data)
    if err then
      if require("sg.ratelimit").is_ratelimit_err(err) then
        require("sg.ratelimit").notify_ratelimit "autocomplete"
        return
      end

      -- TODO: Might want to do something else here?...
      log.debug("Failed to do autocomplete: ", err)
      return
    end

    local items = {}
    for _, item in ipairs(data.items) do
      local trimmed = vim.trim(item.insertText)

      local completion_item = {
        word = trimmed,
        menu = "[cody]",
      }

      table.insert(items, completion_item)
    end

    callback(items)
  end)
end

--- Accepts a completion item and inserts it into the buffer.
--- Uses the builtin complete method, so you have to do something like this:
---
--- <code=lua>
---   vim.keymap.set(
---     "i",
---     "<c-space>",
---     "<C-R>=v:lua.require'sg.cody.complete'.builtin_complete()<CR>"
---   )
--- </code>
---
M.builtin_complete = function()
  local done = false
  M.complete(function(items)
    vim.fn.complete(1, items)
    done = true
  end)

  vim.wait(1000, function()
    return done
  end)

  return ""
end

return M

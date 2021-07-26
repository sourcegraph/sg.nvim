local defaulter = require("telescope.utils").make_default_callable
local previwers = require "telescope.previewers"
local telescope = {}

telescope.sg_previewer = defaulter(function(opts)
  opts = opts or {}
  return previewers.new_buffer_previewer {
    title = "sg",
    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, false)
    end,
    define_preview = function(self, entry, status)
      putils.with_preview_window(status, nil, function()
        local p = from_entry.path(entry, false)
        if p == nil or p == "" then
          return
        end
        vim.cmd("edit " .. p)
      end)
    end,
  }
end, {})

return telescope

local defaulter = require("telescope.utils").make_default_callable
local previewers = require "telescope.previewers"
local putils = require "telescope.previewers.utils"
local from_entry = require "telescope.from_entry"

local telescope = {}

local ns_previewer = vim.api.nvim_create_namespace "sg.telescope.previewers"

telescope.sg_previewer = defaulter(function(opts)
  opts = opts or {}

  local jump_to_line = function(self, bufnr, lnum)
    if lnum and lnum > 0 then
      pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_previewer, "TelescopePreviewLine", lnum - 1, 0, -1)
      pcall(vim.api.nvim_win_set_cursor, self.state.winid, { lnum, 0 })
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd "norm! zz"
      end)
    end

    self.state.last_set_bufnr = bufnr
  end

  return previewers.new_buffer_previewer {
    title = "sg",

    setup = function()
      return { last_set_bufnr = nil }
    end,

    teardown = function(self)
      if self.state and self.state.last_set_bufnr and vim.api.nvim_buf_is_valid(self.state.last_set_bufnr) then
        vim.api.nvim_buf_clear_namespace(self.state.last_set_bufnr, ns_previewer, 0, -1)
      end
    end,

    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, false)
    end,

    define_preview = function(self, entry, status)
      local p = from_entry.path(entry, false)
      if p == nil or p == "" then
        print "... that is one weird entry"
        return
      end

      local bufnr = vim.fn.bufnr(p)
      if bufnr > 0 then
        vim.api.nvim_win_set_buf(status.preview_win, bufnr)
      else
        putils.with_preview_window(status, nil, function()
          vim.cmd("edit " .. p)
          bufnr = vim.api.nvim_get_current_buf()
        end)
      end

      if self.state.last_set_bufnr then
        pcall(vim.api.nvim_buf_clear_namespace, self.state.last_set_bufnr, ns_previewer, 0, -1)
      end

      jump_to_line(self, bufnr, entry.lnum)
      -- vim.cmd [[mode]]
    end,
  }
end, {})

return telescope

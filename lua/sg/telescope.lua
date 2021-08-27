local defaulter = require("telescope.utils").make_default_callable
local previewers = require "telescope.previewers"
local putils = require "telescope.previewers.utils"
local from_entry = require "telescope.from_entry"

local log = require "sg.log"

local telescope = {}

local ns_previewer = vim.api.nvim_create_namespace "sg.telescope.previewers"

-- Usage:
-- lua require'telescope.builtin'.lsp_references { previewer = R'sg.telescope'.sg_previewer.new{} }
telescope.sg_previewer = defaulter(function(opts)
  local jump_to_line = function(self, bufnr, lnum, status)
    if lnum and lnum > 0 then
      pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_previewer, "TelescopePreviewLine", lnum - 1, 0, -1)
      pcall(vim.api.nvim_win_set_cursor, status.preview_win, { lnum, 0 })
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd "norm! zz"
      end)
    end

    self.state.last_set_bufnr = bufnr
  end

  return previewers.Previewer:new {
    title = function()
      return "sg"
    end,

    setup = function()
      return { last_set_bufnr = nil }
    end,

    preview_fn = function(self, entry, status)
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

      jump_to_line(self, bufnr, entry.lnum, status)
    end,
  }
end, {})

telescope.sg_references = function(opts)
  opts = opts or {}

  require("telescope.builtin").lsp_references {
    previewer = telescope.sg_previewer.new(opts),
    layout_strategy = "vertical",
  }
end

return telescope

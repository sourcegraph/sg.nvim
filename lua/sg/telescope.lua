local defaulter = require("telescope.utils").make_default_callable
local from_entry = require "telescope.from_entry"
local previewers = require "telescope.previewers"
local putils = require "telescope.previewers.utils"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values

local log = require "sg.log"

local lib = require "libsg_nvim"

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

telescope.sg_files = function(opts)
  opts = opts or {}

  opts.repository = opts.repository or "github.com/neovim/neovim"
  opts.commit = "ee342d3cef97aa2414c05261b448228ae3277862"
  if not opts.commit then
    opts.commit = lib.get_remote_hash(opts.repository, "ee342d3cef97aa2414c05261b448228ae3277862")
  end

  print("Getting remote files", opts.repository, opts.commit)
  local files = lib.get_files(opts.repository, opts.commit)

  pickers.new({
    finder = finders.new_table {
      results = files,
      entry_maker = function(entry)
        return {
          value = entry,
          text = entry,
          display = entry,
          ordinal = entry,
          filename = string.format("sg://%s@%s/-/%s", opts.repository, opts.commit, entry),
        }
      end,
    },
    sorter = conf.generic_sorter(opts),
    previewer = telescope.sg_previewer.new(opts),
  }):find()
end

telescope.sg_files()

return telescope

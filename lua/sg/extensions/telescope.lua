local defaulter = require("telescope.utils").make_default_callable
local from_entry = require "telescope.from_entry"
local previewers = require "telescope.previewers"
local putils = require "telescope.previewers.utils"
local conf = require("telescope.config").values
local finders = require "telescope.finders"
local entry_display = require "telescope.pickers.entry_display"

local rpc = require "sg.rpc"

local telescope = {}

local ns_previewer = vim.api.nvim_create_namespace "sg.telescope.previewers"

-- Usage:
-- lua require'telescope.builtin'.lsp_references { previewer = R'sg.telescope'.sg_previewer.new{} }
telescope.sg_previewer = defaulter(function(opts)
  opts = opts or {}

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

      local bufnr = assert(vim.fn.bufnr(p), "must have some buffer number")
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

telescope.fuzzy_search_results = function(opts)
  local search = function(input)
    if not input or input == "" then
      print "No search specified"
      return
    end

    rpc.get_search(input, function(err, search_results)
      if err or not search_results then
        print("Got an error:", err, search_results)
        return
      end

      if #search_results == 0 then
        vim.notify "[sg] No search results found"
        vim.cmd.mode()
        return
      end

      local displayer = entry_display.create {
        separator = "|",
        items = {
          { width = 20 },
          { width = 20 },
          { remaining = true },
        },
      }

      local display = function(entry)
        entry = entry.value

        return displayer {
          { entry.repo, "TelescopeResultsLineNr" },
          { entry.file, "TelescopeResultsIdentifier" },
          entry.preview,
        }
      end

      require("telescope.pickers")
        .new({
          sorter = conf.file_sorter(opts),
          finder = finders.new_table {
            results = search_results,
            entry_maker = function(entry)
              return {
                value = entry,
                ordinal = string.format("%s %s", entry.file, entry.preview),
                display = display,
                filename = string.format("sg://%s/-/%s", entry.repo, entry.file),
                row = entry.line + 1,
              }
            end,
          },
        }, {})
        :find()
    end)
  end

  opts = opts or {}
  local input = opts.input
  if input then
    search(input)
  else
    vim.ui.input({ prompt = "Search > " }, search)
  end
end

return telescope

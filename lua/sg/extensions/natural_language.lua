if true then
  error "NOT YET FIXED, NEED TO DO ASYNC"
end

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require "telescope.previewers"
local conf = require("telescope.config").values

local void = require("plenary.async").void

local context = require "sg.cody.context"
local natural = {}

natural.search = function(opts)
  opts = opts or {}

  opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  void(function()
    opts.repo = opts.repo or context.get_origin(opts.bufnr, function()
      error "OH NO"
    end)

    if not opts.repo then
      vim.notify "Failed to determine the repo for your current query"
      return
    end

    opts.query = opts.query or vim.fn.input "Search for > "

    error "did not rewrite embeddings"
    local _, embeds = context.embeddings(opts.repo, opts.query, { code = 25 })

    pickers
      .new({
        sorter = conf.file_sorter(opts),
        previewer = previewers.vim_buffer_vimgrep:new(),
        finder = finders.new_table {
          results = embeds,

          ---@param entry SourcegraphEmbedding
          ---@return table
          entry_maker = function(entry)
            return {
              value = entry,
              ordinal = entry.file,
              display = entry.file,
              filename = entry.file,
              lnum = entry.start,
            }
          end,
        },
      }, {})
      :find()
  end)()
end

return natural

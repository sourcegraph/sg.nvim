RELOAD "sg"

local Job = require "plenary.job"
local filetype = require "plenary.filetype"

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"

local actions = require "telescope.actions"
local action_set = require "telescope.actions.set"
local action_state = require "telescope.actions.state"

local conf = require("telescope.config").values
local Previewer = require "telescope.previewers.previewer"
local p_utils = require "telescope.previewers.utils"

local git = require "sg.git"
local worktree = require "sg.worktree"

local once = require("sg.utils").once

local get_access_token = once(function()
  return os.getenv "SRC_ACCESS_TOKEN"
end)

local get_endpoint = once(function()
  return os.getenv "SRC_ENDPOINT"
end)

if vim.fn.executable "src" == 0 then
  error "src is required"
end

local M = {}

local format_options = function(opts)
  local terms = {}
  for k, v in pairs(opts) do
    if type(k) ~= "number" then
      table.insert(terms, string.format("%s:%s", k, v))
    end
  end

  for _, v in ipairs(opts) do
    table.insert(terms, v)
  end

  return table.concat(terms, " ")
end

M.run = function(cwd, input)
  local remote = git.default_remote_url(cwd)

  local repo = remote:gsub("https://", "")
  -- local rev = "04097305904e48788eeb911ddf0f5f131ad66845"
  -- local rev = "88e68e8c698e1990da685dfe806a978c4ddcf76c"
  -- local rev = "facca2a6e81cdbaa86d13c101f2f6adad5f2f59f"
  local rev = nil

  local options = {
    input,
    rev = rev,
    repo = repo,
  }

  local j = Job:new {
    "/home/tjdevries/.local/bin/src",
    "search",
    "-json",
    format_options(options),
    env = {
      SRC_ACCESS_TOKEN = get_access_token(),
      SRC_ENDPOINT = get_endpoint(),
    },
  }

  local output = j:sync()

  -- vim.api.nvim_buf_set_lines(248, 0, -1, false, output)
  -- if true then
  --   return
  -- end

  local result = vim.fn.json_decode(table.concat(output, ""))

  M.result_to_telescope(remote, result)
end

M.result_to_telescope = function(remote_url, result)
  if not result.Results then
    return
  end

  local entries = {}
  local line_map = {}
  for _, match in ipairs(result.Results) do
    line_map[match.file.path] = vim.split(match.file.content, "\n")

    for _, line_match in ipairs(match.lineMatches) do
      table.insert(entries, {
        path = match.file.path,
        commit = match.file.commit.oid,
        url = match.file.url,

        lnum = line_match.lineNumber,
        col = line_match.offsetAndLengths[1][1] + 1,
      })
    end
  end

  pickers.new({}, {
    prompt_title = "Sourcegraph (WIP)",
    finder = finders.new_table {
      results = entries,
      entry_maker = function(e)
        local line = line_map[e.path][e.lnum + 1]
        return {
          value = e,
          -- display = string.format("%s : %s", e.commit, line),
          display = e.path .. ": " .. (line or ""),
          ordinal = line,

          -- Location information
          lnum = e.lnum + 1,
          col = e.col,
        }
      end,
    },
    sorter = conf.generic_sorter {},
    previewer = Previewer:new {
      preview_fn = function(_, entry, status)
        local preview_win = status.preview_win
        local bufnr = vim.api.nvim_win_get_buf(preview_win)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, line_map[entry.value.path])
        vim.api.nvim_win_set_cursor(preview_win, { entry.value.lnum, 0 })

        p_utils.highlighter(bufnr, filetype.detect(entry.value.path))
        vim.api.nvim_buf_add_highlight(bufnr, 0, "Visual", entry.value.lnum, 0, -1)
      end,
    },

    attach_mappings = function(_, map)
      action_set.select:enhance {
        -- TODO: This is a bit of a weird hack to make it seem like we knew this file location ahead of time.
        pre = function(prompt_bufnr, command)
          local edit_type = action_state.select_key_to_edit_key(command)
          local entry = action_state.get_selected_entry()

          entry.path = worktree.setup_for_edit(remote_url, entry.value.commit, entry.value.path)
          entry.filename = entry.path
        end,

        post = function()
          local bufnr = vim.api.nvim_get_current_buf()

          vim.bo[bufnr].readonly = true
          -- todo: local working directory
          -- todo: statusline update?
        end,
      }

      return true
    end,
  }):find()
end

-- M.lens()
-- M.test("~/sourcegraph/sourcegraph", "projectResult{...} patternType:structural")
-- M.test("~/plugins/telescope-sourcegraph.nvim", "function")
-- M.run("~/sourcegraph/sourcegraph", "Query file:go")

-- .cache/sg_telescope/<url>/<commit>/<path>

return M

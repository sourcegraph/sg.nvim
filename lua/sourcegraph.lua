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

M.default_url_str = function(cwd)
  return (string.gsub(git.default_remote_url(cwd), "https://", ""))
end

M.test = function(cwd, input)
  local remote = M.default_url_str(cwd)
  local j = Job:new {
    "/home/tjdevries/.local/bin/src",
    "search",
    "-json",
    string.format("repo:^%s$ %s", remote, input),
    env = {
      SRC_ACCESS_TOKEN = get_access_token(),
      SRC_ENDPOINT = get_endpoint(),
    },
  }

  local output = j:sync()

  -- local bufnr = 190
  -- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
  -- if true then return end

  local result = vim.fn.json_decode(table.concat(output, ""))

  M.result_to_telescope(remote, result)
end

-- M.lens = function()
--   local result = vim.fn.json_decode(table.concat(Job
--     :new({
--       "src",
--       "search",
--       "-json",
--       "repo:^github.com/neovim/neovim$ " .. vim.fn.input "Function Name > ",
--       env = {
--         SRC_ACCESS_TOKEN = get_access_token(),
--         SRC_ENDPOINT = get_endpoint(),
--       },
--     })
--     :sync(), ""))

--   M.result_to_telescope(result)
-- end

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
        lineNumber = line_match.lineNumber,
      })
    end
  end

  pickers.new({}, {
    prompt_title = "Sourcegraph (WIP)",
    finder = finders.new_table {
      results = entries,
      entry_maker = function(e)
        local line = line_map[e.path][e.lineNumber + 1]
        return {
          value = e,
          -- display = string.format("%s : %s", e.commit, line),
          display = e.path .. ": " .. line,
          ordinal = line,
        }
      end,
    },
    sorter = conf.generic_sorter {},
    previewer = Previewer:new {
      preview_fn = function(_, entry, status)
        local preview_win = status.preview_win
        local bufnr = vim.api.nvim_win_get_buf(preview_win)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, line_map[entry.value.path])
        vim.api.nvim_win_set_cursor(preview_win, { entry.value.lineNumber, 0 })

        p_utils.highlighter(bufnr, filetype.detect(entry.value.path))
        vim.api.nvim_buf_add_highlight(bufnr, 0, "Visual", entry.value.lineNumber, 0, -1)
      end,
    },

    attach_mappings = function(prompt_bufnr, map)
      action_set.edit:replace(function(e)
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        -- print(remote_url)
        -- print(entry.value.commit)
        -- print(entry.value.path)

        vim.schedule(function()
          worktree.edit(remote_url, entry.value.commit, entry.value.path)
        end)
      end)

      return true
    end,
  }):find()
end

-- M.lens()
M.test("~/plugins/telescope-sourcegraph.nvim", "function")

-- .cache/sg_telescope/<url>/<commit>/<path>

return M

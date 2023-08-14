local void = require("plenary.async").void

local ns = vim.api.nvim_create_namespace "cody-diffview"

local bufnr = 15
local print_buf = 16
local print = function(x)
  vim.api.nvim_buf_set_lines(print_buf, -1, -1, false, vim.split(x, "\n"))
end

vim.api.nvim_buf_set_lines(print_buf, 0, -1, false, {})
void(function()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- if true then
  --   return
  -- end

  local contents = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  local expected = [[
-- Require the void async utility from plenary
local void = require("plenary.async").void 

-- Create a namespace to use for highlights
local ns = vim.api.nvim_create_namespace "cody-diffview"

-- Print function to output text to a buffer 
local print = function(x)
  vim.api.nvim_buf_set_lines(194, -1, -1, false, vim.split(x, "\n"))
end

-- Clear lines in target buffer
vim.api.nvim_buf_set_lines(194, 0, -1, false, {})
]]

  local err, data = require("sg.rpc").get_diff(contents, expected)
  if err then
    return print("OH NO", err)
  end

  print(vim.inspect(data))

  -- vim.print(data)
  local inserted = 0
  local deleted = 0
  for _, change in ipairs(data) do
    if change.tag == "equal" then
      -- pass
    elseif change.tag == "insert" then
      if #change.values == 1 then
        local content = change.values[1][2]
        content = string.gsub(content, "\n", "")
        vim.api.nvim_buf_set_extmark(bufnr, ns, change.new_index - inserted, 0, {
          virt_lines_above = true,
          virt_lines = { { { content, "DiffAdded" } } },
        })
      else
        print "multi insert"
        print(vim.inspect(change))

        local col = 0
        for _, value in ipairs(change.values) do
          local hl, text = unpack(value)
          if hl then
            vim.api.nvim_buf_set_extmark(bufnr, ns, change.new_index - inserted, col, {
              virt_text = { { text, "DiffAdded" } },
              virt_text_pos = "inline",
            })
          end

          col = col + #text
        end
      end

      inserted = inserted + 1
    elseif change.tag == "delete" then
      deleted = deleted + 1

      if #change.values == 1 then
        vim.api.nvim_buf_set_extmark(bufnr, ns, change.old_index, 0, {
          -- hl_group = "DiffDelete",
          -- end_col = -1,
          line_hl_group = "DiffDelete",
        })
      else
        print "multi delete"
        print(vim.inspect(change))

        local col = 0
        for _, value in ipairs(change.values) do
          local hl, text = unpack(value)
          if hl then
            vim.api.nvim_buf_add_highlight(bufnr, ns, "DiffChange", change.old_index, col, col + #text)
          end

          col = col + #text
        end
      end
    else
      print "unhandled"
      print(vim.inspect(change))
      -- print(vim.inspect(change))
    end
  end
end)()

-- local bufnr = 5
-- local contents = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
-- local expected = { "helo!", "world" }
-- || {
-- ||   new_index = 0,
-- ||   old_index = 0,
-- ||   tag = "equal",
-- ||   values = { { false, "line 1\n" } }
-- || }
-- || {
-- ||   old_index = 1,
-- ||   tag = "delete",
-- ||   values = { { false, "start " }, { true, "helo" }, { false, " end\n" } }
-- || }
-- || {
-- ||   new_index = 1,
-- ||   tag = "insert",
-- ||   values = { { false, "start " }, { true, "hello" }, { false, " end\n" } }
-- || }
-- || {
-- ||   new_index = 2,
-- ||   old_index = 2,
-- ||   tag = "equal",
-- ||   values = { { false, "line 3" } }
-- || }
-- --
-- -- --[[@as table]]
-- -- local get_diff = function(a, b)
-- --   if type(a) == "table" then
-- --     a = table.concat(a, "\n")
-- --   end
-- --
-- --   if type(b) == "table" then
-- --     b = table.concat(b, "\n")
-- --   end
-- --
-- --   return vim.diff(a, b, {
-- --     result_type = "indices",
-- --     algorithm = "myers",
-- --     linematch = 50,
-- --   }),
-- --     vim.diff(a, b, {})
-- -- end
-- -- local diffed = vim.diff(table.concat(contents, "\n"), table.concat(expected, "\n"), {
-- --   result_type = "indices",
-- --   algorithm = "myers",
-- --   linematch = 1,
-- -- })
-- --
-- -- vim.print(diffed)
-- --
-- -- for _, chunk in ipairs(diffed) do
-- --   -- vim.print(chunk)
-- --   local start, count, start_b, count_b = unpack(chunk)
-- --   local line = contents[start]
-- --   local new = expected[start_b]
-- --   print("line:", line, " | ", new)
-- --   vim.print(get_diff(line, new))
-- -- end

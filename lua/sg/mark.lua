---@class CodyMarkWrapper
---@field bufnr number
---@field ns number
---@field id number
local Mark = {}
Mark.__index = Mark

function Mark.init(opts)
  local ns = assert(opts.ns, "Must pass a namespace")
  local bufnr = assert(opts.bufnr, "Must pass a bufnr")

  local start_row = opts.start_row
  local start_col = opts.start_col or 0
  local end_row = opts.end_row
  local end_col = opts.end_col

  return setmetatable({
    bufnr = bufnr,
    ns = ns,
    id = vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      right_gravity = false,
      end_right_gravity = (end_row and end_col and true) or nil,
    }),
  }, Mark)
end

function Mark:details()
  return vim.api.nvim_buf_get_extmark_by_id(self.bufnr, self.ns, self.id, { details = true })
end

function Mark:start_pos(details)
  details = details or self:details()
  return { row = details[1], col = details[2] }
end

function Mark:end_pos(details)
  details = details or self:details()
  return { row = details[3].end_row, col = details[3].end_col }
end

function Mark:text(details)
  details = details or self:details()
  local start_pos = self:start_pos(details)
  local end_pos = self:end_pos(details)
  return table.concat(
    vim.api.nvim_buf_get_text(self.bufnr, start_pos.row, start_pos.col, end_pos.row, end_pos.col, {}),
    "\n"
  )
end

-- function Mark.get(bufnr, ns, id) end

return Mark

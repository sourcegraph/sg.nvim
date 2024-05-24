local uv = vim.uv or vim.loop
local log = require "sg.log"

local ns = vim.api.nvim_create_namespace "cody-chat-messages"

--[[
TODO:
-  Would be cool to see how far the ends of the strings match as well, so
   we fill the text inside without redrawing the last ones every time
--]]

--- Insert text at the end of the mark
---@param mark CodyMarkWrapper
---@param text string
local insert_text = function(mark, text)
  local pos = mark:end_pos()
  if text == "\n" then
    vim.api.nvim_buf_set_text(mark.bufnr, pos.row, pos.col, pos.row, pos.col, {
      "",
      "",
    })
  else
    vim.api.nvim_buf_set_text(mark.bufnr, pos.row, pos.col, pos.row, pos.col, {
      text,
    })
  end
end

---@class CodyTypewriter
---@field timer uv_timer_t?
---@field index number
---@field text string
---@field interval number: The average ms between characters
---@field parent_transcript sg.cody.Transcript
local Typewriter = {}

Typewriter.ns = ns

--- Create a new typewriter
---@return CodyTypewriter
Typewriter.init = function(opts)
  opts = opts or {}

  return setmetatable({
    timer = nil,
    index = 0,
    text = "",
    interval = opts.interval or 6,
    parent_transcript = assert(opts.transcript, "must be associated with a transcript"),
  }, { __index = Typewriter })
end

function Typewriter:set_text(text)
  self.text = text
end

--- Render a typewriter message
---@param bufnr number
---@param win number
---@param mark CodyMarkWrapper
---@param opts { interval: number? }?
function Typewriter:render(bufnr, win, mark, opts)
  opts = opts or {}

  local current_text = mark:text()
  if current_text == self.text then
    log.trace("skipping cause same text...", current_text, self.text)
    return
  end

  local interval = opts.interval or self.interval
  if interval <= 0 then
    local details = mark:details()
    local start_pos = mark:start_pos(details)
    local end_pos = mark:end_pos(details)
    vim.api.nvim_buf_set_text(
      bufnr,
      start_pos.row,
      start_pos.col,
      end_pos.row,
      end_pos.col,
      vim.split(self.text, "\n")
    )
    return
  end

  self.timer = self.timer or uv.new_timer()
  if self.timer:is_active() then
    return
  end

  local chars_to_insert = {}
  local render_fn = function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return self:stop()
    end

    if not self.timer then
      return
    end

    local details = mark:details()
    local start_pos = mark:start_pos(details)
    local buffer_text = mark:text(details)

    if buffer_text == self.text then
      return
    end

    local repeat_time = interval

    -- Add a touch of jitter
    local interval_jitter = math.floor(interval * 0.8)
    repeat_time = repeat_time + math.random(-1 * interval_jitter, interval_jitter)

    -- Make it so that if we haved a lot of characters to add, we send them more quickly
    repeat_time = repeat_time * (1 / (#chars_to_insert + 1))

    self.timer:set_repeat(repeat_time)

    if buffer_text ~= string.sub(self.text, 1, self.index) then
      local shared_rows = 0
      local shared_col = 0
      for i = 1, #self.text do
        if string.sub(self.text, i, i) == "\n" then
          shared_rows = shared_rows + 1
          shared_col = 0
        else
          shared_col = shared_col + 1
        end

        if string.sub(self.text, i, i) ~= string.sub(buffer_text, i, i) then
          self.index = i - 1
          shared_col = shared_col - 1
          break
        end
      end

      -- Sometimes we access out of the buffer range, but I think it's fine to just pcall in that case...
      --    We should probably double check this later though
      local end_pos = mark:end_pos(details)
      pcall(
        vim.api.nvim_buf_set_text,
        bufnr,
        start_pos.row + shared_rows,
        shared_col,
        end_pos.row,
        end_pos.col,
        {}
      )
    end

    if self.index >= #self.text then
      log.trace("done", self.text)
      return self:stop()
    end

    local next_char = string.sub(self.text, self.index + 1, self.index + 1)
    if next_char == "" then
      self.index = self.index + 1
      log.trace("empty next char:", self.index, self.text)
      return
    end

    if next_char == "\n" then
      self.index = self.index + 1
      insert_text(mark, next_char)
    else
      if #chars_to_insert == 0 then
        self.index = self.index + 1
        next_char = string.sub(self.text, self.index, self.index)

        -- Funny options to explore later, could be fun easter eggs
        -- chars_to_insert = { "✶", "✷", "✸", next_char }
        -- chars_to_insert = { "💣", "💥", "🔥", next_char }
        -- if next_char ~= " " then
        --   for _ = 1, math.random(2, 8) do
        --     table.insert(chars_to_insert, string.char(math.random(1, 26) + 96))
        --   end
        -- end

        table.insert(chars_to_insert, next_char)
      end

      local ch = table.remove(chars_to_insert, 1)
      insert_text(mark, ch)
    end

    local linecount = vim.api.nvim_buf_line_count(bufnr)
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_win_set_cursor(win, { linecount, 0 })
    end
  end

  self.timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      local ok, err = pcall(render_fn)
      if not ok then
        log.info("[sg.typewriter] error while writing:", err)
        return self:stop()
      end
    end)
  )
end

function Typewriter:stop()
  if self.timer then
    self.timer:stop()
    self.timer = nil
  end
end

return Typewriter

local M = {}

local store = {}

M.map = function(bufnr, mode, key, desc, cb)
  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      M.map(bufnr, m, key, desc, cb)
    end

    return
  end

  if not store[bufnr] then
    store[bufnr] = {
      maps = {},
    }

    vim.api.nvim_buf_attach(bufnr, false, {
      on_detach = function()
        store[bufnr] = nil
      end,
    })
  end

  table.insert(store[bufnr].maps, { mode = mode, key = key, desc = desc })

  vim.keymap.set(mode, key, cb, {
    desc = desc,
  })
end

M.help = function(bufnr)
  local maps = store[bufnr]
  if not maps then
    print "no keymaps for this bufnr"
    return
  end

  local width = 0
  local lines = {}
  for _, map in ipairs(maps.maps) do
    local line = string.format("mode: %s, key: %6s | %s", map.mode, map.key, map.desc)
    width = math.max(width, #line)
    table.insert(lines, line)
  end

  -- TODO: This isn't centered :/ It's not great
  vim.lsp.util.open_floating_preview(
    lines,
    "",
    vim.lsp.util.make_floating_popup_options(width + 4, #lines + 2, {
      zindex = 200,
    })
  )
end

return M

local log = require "sg.log"
local lib = require "sg.lib"

local transform_path = require("sg.directory").transform_path

local ns = vim.api.nvim_create_namespace "sg-bufread"

--- Temporarily allows modifying the buffer, and then sets nomodifiable
---@param bufnr number
---@param cb function
local with_modifiable = function(bufnr, cb)
  vim.bo[bufnr].modifiable = true
  local res = cb()
  vim.bo[bufnr].modifiable = false
  return res
end

local M = {}

M.edit = function(path)
  ---@type boolean, SgEntry
  local ok, entry = pcall(lib.get_entry, path)
  if not ok then
    local contents = {}
    if type(entry) == "string" then
      contents = vim.split(entry, "\n")
    else
      vim.list_extend(contents, vim.split(tostring(entry), "\n"))
    end

    table.insert(contents, 1, "failed to load file")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, contents)
    return
  end

  if not entry then
    log.info "Failed to retrieve path info"
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  if entry.type == "directory" then
    return M._open_remote_folder(
      bufnr,
      entry.bufname,
      entry.data --[[@as SgDirectory]]
    )
  elseif entry.type == "file" then
    return M._open_remote_file(
      bufnr,
      entry.bufname,
      entry.data --[[@as SgFile]]
    )
  else
    error("unknown path type: " .. entry.type)
  end
end

local manage_new_buffer = function(bufnr, bufname, create)
  local existing_bufnr = vim.fn.bufnr(bufname)

  -- If we have an existing buffer, then set the current buffer
  -- to that buffer and then quit
  if existing_bufnr ~= -1 and bufnr ~= existing_bufnr then
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    vim.api.nvim_buf_set_name(bufnr, bufname)
    create()
  end
end

--- Open a remote file
---@param bufnr number
---@param bufname string
---@param data SgDirectory
M._open_remote_folder = function(bufnr, bufname, data)
  manage_new_buffer(bufnr, bufname, function()
    vim.bo[bufnr].buftype = "nofile"

    ---@type boolean, SgEntry[]
    local ok, entries = pcall(lib.get_remote_directory_contents, data.remote, data.oid, data.path)
    if not ok then
      error(entries)
    end

    with_modifiable(bufnr, function()
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      for idx, entry in ipairs(entries) do
        -- TODO: Highlights
        local line, highlights = transform_path(entry.data.path, entry.type == "directory")

        local start = -1
        if idx == 1 then
          start = 0
        end

        vim.api.nvim_buf_set_lines(bufnr, start, -1, false, { line })
        if highlights then
          vim.api.nvim_buf_add_highlight(bufnr, ns, highlights, idx - 1, 1, 3)
        end
      end
    end)

    local get_row = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      return cursor[1]
    end

    local get_entry = function()
      local row = get_row()
      return entries[row]
    end

    -- Sets <CR> to open the file
    vim.keymap.set("n", "<CR>", function()
      local selected = get_entry()
      vim.cmd.edit(selected.bufname)
    end, { buffer = bufnr })

    -- Sets <tab> to expand a directory
    vim.keymap.set("n", "<tab>", function()
      local selected = get_entry()
      if selected.type ~= "directory" then
        return
      end

      local row = get_row()
      local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      local indent = #(string.match(current_line, "^(%s+)") or "") / 2

      local children = lib.get_remote_directory_contents(selected.data.remote, selected.data.oid, selected.data.path)
      with_modifiable(bufnr, function()
        for idx, entry in ipairs(children) do
          -- TODO: Highlights
          local line, highlights = transform_path(entry.data.path, entry.type == "directory")
          line = string.rep("  ", indent + 1) .. line

          local idx_row = row + idx - 1
          vim.api.nvim_buf_set_lines(bufnr, idx_row, idx_row, false, { line })
          vim.api.nvim_buf_add_highlight(bufnr, ns, highlights, idx_row, 1 + indent * 2, 3 + indent * 2)

          table.insert(entries, row + idx, entry)
        end
      end)
    end)

    -- Sets <S-tab> to collapse a directory
    vim.keymap.set("n", "<S-tab>", function()
      local selected = get_entry()
      if selected.type ~= "directory" then
        return
      end

      -- TODO: Could possibly do this only using indents, but it's fine
      local row = get_row()
      local children = lib.get_remote_directory_contents(selected.data.remote, selected.data.oid, selected.data.path)
      with_modifiable(bufnr, function()
        for _ in ipairs(children) do
          vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, {})
          table.remove(entries, row + 1)
        end
      end)
    end)
  end)
end

--- Opens a remote file
---@param bufnr number
---@param bufname string
---@param data SgFile
M._open_remote_file = function(bufnr, bufname, data)
  manage_new_buffer(bufnr, bufname, function()
    local ok, contents = pcall(lib.get_remote_file_contents, data.remote, data.oid, data.path)
    if not ok then
      local errmsg
      if type(contents) == "string" then
        errmsg = vim.split(contents, "\n")
      else
        errmsg = vim.split(tostring(contents), "\n")
      end

      table.insert(errmsg, 1, "failed to get contents")

      return with_modifiable(bufnr, function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, errmsg)
      end)
    end

    with_modifiable(bufnr, function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    end)

    vim.cmd [[doautocmd BufRead]]
    vim.bo[bufnr].filetype = vim.filetype.match { filename = data.path, contents = contents } or ""
  end)

  -- TODO: I don't love calling this directly here...
  --  But I'm not sure *why* it doesn't attach using autocmds and listening
  --
  -- This should be free to call multiple times on the same buffer
  --    So I'm not worried about that for now (but we should check later)
  require("sg.lsp").attach(bufnr)
  if data.position then
    print("Data Position:", data.position)
    -- error "TODO: handle position"
    -- pcall(vim.api.nvim_win_set_cursor, 0, { remote_file.line, remote_file.col or 0 })
  end
end

return M

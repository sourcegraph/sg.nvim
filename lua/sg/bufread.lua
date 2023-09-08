local filetype = require "plenary.filetype"
local void = require("plenary.async").void

local log = require "sg.log"
local rpc = require "sg.rpc"

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

--- Edit a file
---@param bufnr number: The buffer to load the contents in
---@param path string: The URI to open
---@param callback function?: Optional callback to specify that the loading is complete
M.edit = function(bufnr, path, callback)
  vim.bo[bufnr].buftype = "nofile"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Loading..." })

  void(function()
    local err, entry = rpc.get_entry(path)
    if err ~= nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(vim.inspect(err), "\n"))
      return
    end

    if not entry then
      log.info "Failed to retrieve path info"
      return
    end

    if entry.type == "directory" then
      M._open_remote_folder(bufnr, entry.bufname, entry.data --[[@as SgDirectory]])
    elseif entry.type == "file" then
      M._open_remote_file(bufnr, entry.bufname, entry.data --[[@as SgFile]])
    elseif entry.type == "repo" then
      M._open_remote_repo(bufnr, entry.bufname, entry.data --[[@as SgRepo]])
    else
      error("unknown path type: " .. entry.type)
    end

    if callback then
      callback()
    end
  end)()
end

local manage_new_buffer = function(bufnr, bufname, create)
  local existing_bufnr = vim.fn.bufnr(bufname)

  -- If we have an existing buffer, then set the current buffer
  -- to that buffer and then quit
  if existing_bufnr ~= -1 and bufnr ~= existing_bufnr then
    vim.api.nvim_win_set_buf(0, existing_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    -- Rename the file, but keep the alternate file.
    --  It would be really nice if there was an easier way to do this...
    vim.cmd(string.format("keepalt file! %s", bufname))

    create()
  end
end

--- Open a remote file
---@param bufnr number
---@param bufname string
---@param data SgDirectory
M._open_remote_folder = function(bufnr, bufname, data)
  manage_new_buffer(bufnr, bufname, function()
    local err, entries = rpc.get_directory_contents(data.remote, data.oid, data.path)
    if err ~= nil or not entries then
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

      void(function()
        local err, children = rpc.get_directory_contents(selected.data.remote, selected.data.oid, selected.data.path)
        if err ~= nil or not children then
          print "Failed to load directory"
          return
        end

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
      end)()
    end)

    -- Sets <S-tab> to collapse a directory
    vim.keymap.set("n", "<S-tab>", function()
      local selected = get_entry()
      if selected.type ~= "directory" then
        return
      end

      -- TODO: Could possibly do this only using indents, but it's fine
      local row = get_row()

      void(function()
        local err, children = rpc.get_directory_contents(selected.data.remote, selected.data.oid, selected.data.path)
        if err ~= nil or not children then
          print "unable to load directory contents"
          return
        end

        with_modifiable(bufnr, function()
          for _ in ipairs(children) do
            vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, {})
            table.remove(entries, row + 1)
          end
        end)
      end)()
    end)
  end)
end

--- Opens a remote file
---@param bufnr number
---@param bufname string
---@param data SgFile
M._open_remote_file = function(bufnr, bufname, data)
  manage_new_buffer(bufnr, bufname, function()
    local err, contents = rpc.get_file_contents(data.remote, data.oid, data.path)
    if err ~= nil or not contents then
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

    vim.api.nvim_exec_autocmds("BufRead", {})
    vim.bo[bufnr].filetype = vim.filetype.match { filename = data.path, contents = contents }
      or filetype.detect(data.path, {})
  end)

  -- TODO: I don't love calling this directly here...
  --  But I'm not sure *why* it doesn't attach using autocmds and listening
  --
  -- This should be free to call multiple times on the same buffer
  --    So I'm not worried about that for now (but we should check later)
  require("sg.lsp").attach(bufnr)

  if data.position then
    -- error "TODO: handle position"
    -- pcall(vim.api.nvim_win_set_cursor, 0, { remote_file.line, remote_file.col or 0 })
  end
end

--- Open a remote repo
---@param bufnr any
---@param bufname any
---@param data SgRepo
M._open_remote_repo = function(bufnr, bufname, data)
  M._open_remote_folder(bufnr, bufname, { remote = data.remote, oid = data.oid, path = "/" })
end

return M

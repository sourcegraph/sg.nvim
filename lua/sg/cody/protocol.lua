local debounce = require "sg.vendored.debounce"

local proto = {}

local if_nil = function(x, val)
  if x == nil then
    return val
  end

  return x
end

local bufstate = {}

--- Get textdocument for a buffer
---@param bufnr number
---@param opts table?
---@return CodyTextDocument
proto.get_text_document = function(bufnr, opts)
  if not bufstate[bufnr] then
    bufstate[bufnr] = {}
  end

  opts = opts or {}
  opts.content = if_nil(opts.content, true)
  -- opts.selection = if_nil(opts.selection, false)

  -- TODO: We need to handle renames and some other goofy stuff like that
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    bufstate[bufnr].name = name
  end

  local text_document = {
    filePath = name,
  }

  if opts.content then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    text_document.content = table.concat(lines, "\n")
  end

  -- TODO:
  if opts.selection then
    text_document.selection = opts.selection
  end

  return text_document
end

local debounce_handles = {}

proto.did_open = function(bufnr)
  if debounce_handles[bufnr] then
    return
  end

  if not proto.document.is_useful(bufnr) then
    return
  end

  -- Open the file
  require("sg.cody.rpc").notify("textDocument/didOpen", proto.get_text_document(bufnr))

  -- Notify of changes
  local notify_changes, timer = debounce.debounce_trailing(function()
    require("sg.cody.rpc").notify("textDocument/didChange", proto.get_text_document(bufnr))
  end, 500)

  debounce_handles[bufnr] = timer

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_attach(bufnr, true, {
        on_lines = notify_changes,
      })
    end
  end)
end

proto.did_close = function(bufnr)
  if debounce_handles[bufnr] then
    local handle = debounce_handles[bufnr]
    if not handle:is_closing() then
      handle:close()
    end

    debounce_handles[bufnr] = nil
  end

  if not proto.document.is_useful(bufnr) then
    return
  end

  local doc = proto.get_text_document(bufnr, { content = false })
  if not doc.filePath then
    return
  end

  require("sg.cody.rpc").notify("textDocument/didClose", doc)
end

proto.did_focus = function(bufnr)
  if not proto.document.is_useful(bufnr) then
    return
  end

  require("sg.cody.rpc").notify(
    "textDocument/didFocus",
    proto.get_text_document(bufnr, { content = false })
  )
end

proto.exit = function()
  local rpc = require "sg.cody.rpc"

  if not rpc.client then
    return
  end

  rpc.shutdown()
  rpc.exit()
end

proto.document = {
  --- Determines if buffer is useful
  ---@param bufnr any
  is_useful = function(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return false
    end

    local bo = vim.bo[bufnr]
    if not bo.buflisted then
      return false
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    if not name or name == "" then
      return false
    end

    return true
  end,
}

---@class cody.TextDocumentEditParams
---@field uri string
---@field edits cody.TextEdit[]
---@field options? { undoStopBefore: boolean, undoStopAfter: boolean }

---@alias cody.TextEdit cody.ReplaceTextEdit | cody.InsertTextEdit | cody.DeleteTextEdit

---@class cody.ReplaceTextEdit
---@field type 'replace'
---@field range cody.Range
---@field value string
---unsupported field metadata? vscode.WorkspaceEditEntryMetadata

---@class cody.InsertTextEdit
---@field type 'insert'
---@field position cody.Position
---@field value string
---unsupported metadata?: vscode.WorkspaceEditEntryMetadata

---@class cody.DeleteTextEdit
---@field type 'delete'
---@field range cody.Range
---unsupported metadata? vscode.WorkspaceEditEntryMetadata

--- Apply a single text edit to a buffer
---@param bufnr number
---@param edit cody.TextEdit
proto.apply_text_edit = function(bufnr, edit)
  if edit.type == "replace" then
    local replace = edit ---@as cody.ReplaceTextEdit

    local range = replace.range
    local start = range.start
    local finish = range["end"]

    vim.api.nvim_buf_set_text(
      bufnr,
      start.line,
      start.character,
      finish.line,
      finish.character,
      vim.split(replace.value, "\n")
    )
  elseif edit.type == "insert" then
    local insert = edit ---@as cody.InsertTextEdit

    local line = insert.position.line
    local character = insert.position.character
    vim.api.nvim_buf_set_text(
      bufnr,
      line,
      character,
      line,
      character,
      vim.split(insert.value, "\n")
    )
  elseif edit.type == "delete" then
    local delete = edit ---@as cody.DeleteTextEdit
    local range = delete.range
    local start = range.start
    local finish = range["end"]

    vim.api.nvim_buf_set_text(bufnr, start.line, start.character, finish.line, finish.character, {})
  else
    error("Unknown edit type: " .. edit.type)
  end
end

--- Handle text document edits
---@param _ any
---@param params cody.TextDocumentEditParams
proto.handle_text_document_edit = function(_, params)
  local bufnr = vim.uri_to_bufnr(params.uri)
  for _, edit in ipairs(params.edits) do
    proto.apply_text_edit(bufnr, edit)
  end

  return true
end

---@class cody.UntitledTextDocument
---@field uri string
---@field content? string
---@field language? string

--- Open an untitled document
---@param _ any
---@param params cody.UntitledTextDocument
proto.handle_text_document_open_untitled_document = function(_, params)
  vim.cmd.edit(params.uri)
  if params.content then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(params.content, "\n"))
  end
end

---@class cody.WorkspaceEditParams
---@field operations cody.WorkspaceEditOperation[]
---@field metadata? cody.vscode.WorkspaceEditMetadata

---@alias cody.WorkspaceEditOperation  cody.CreateFileOperation | cody.RenameFileOperation | cody.DeleteFileOperation | cody.EditFileOperation

---@class cody.WriteFileOptions
---@field overwrite? boolean
---@field ignoreIfExists? boolean

---@class cody.CreateFileOperation
---@field type 'create-file'
---@field uri string
---@field options? cody.WriteFileOptions
---@field textContents string
---@field metadata? cody.vscode.WorkspaceEditEntryMetadata

---@class cody.RenameFileOperation
---@field type 'rename-file'
---@field oldUri string
---@field newUri string
---@field options? cody.WriteFileOptions
---@field metadata? cody.vscode.WorkspaceEditEntryMetadata

---@class cody.DeleteFileOperation
---@field type 'delete-file'
---@field uri string
---@field deleteOptions? { recursive:  boolean, ignoreIfNotExists: boolean }
---@field metadata? cody.vscode.WorkspaceEditEntryMetadata

---@class cody.EditFileOperation
---@field type 'edit-file'
---@field uri string
---@field edits cody.TextEdit[]

---@class cody.vscode.WorkspaceEditMetadata
---@field isRefactoring? boolean

---@class cody.vscode.WorkspaceEditEntryMetadata
---@field needsConfirmation boolean
---@field label string
---@field description? string

--- Handle a workspace edit
---@param _ any
---@param params cody.WorkspaceEditParams
proto.handle_workspace_edit = function(_, params)
  for _, operation in ipairs(params.operations) do
    print("operation: ", vim.inspect(operation))
    if operation.type == "create-file" then
      local create = operation ---@as cody.CreateFileOperation
      --- uri string
      --- options? cody.WriteFileOptions
      --- textContents string
      --- metadata? cody.vscode.WorkspaceEditEntryMetadata

      local filename = vim.uri_to_fname(create.uri)

      -- TODO: create.options -> flags
      local flags = nil
      vim.fn.writefile(vim.split(create.textContents, "\n"), filename, flags)
    elseif operation.type == "rename-file" then
      local rename = operation ---@as cody.RenameFileOperation

      -- TODO: handle options
      vim.fn.rename(vim.uri_to_fname(rename.oldUri), vim.uri_to_fname(rename.newUri))
    elseif operation.type == "delete-file" then
      local delete = operation ---@as cody.DeleteFileOperation

      -- TODO: delete.deleteOptions
      vim.fn.delete(vim.uri_to_fname(delete.uri))
    elseif operation.type == "edit-file" then
      local edit = operation ---@as cody.EditFileOperation

      local bufnr = vim.uri_to_bufnr(edit.uri)
      for _, text_edit in ipairs(edit.edits) do
        proto.apply_text_edit(bufnr, text_edit)
      end
    else
      error("Unknown workspace edit operation: " .. operation.type)
    end
  end
end

return proto

---@class SgPosition
---@field line number?
---@field col number?

---@class SgEntry
---@field type "file" | "directory"
---@field bufname string
---@field data SgFile | SgDirectory

---@class SgDirectory
---@field remote string
---@field oid string
---@field path string

---@class SgFile
---@field remote string
---@field oid string
---@field path string
---@field position nil|SgPosition

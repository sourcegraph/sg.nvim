---@class SgPosition
---@field line number?
---@field col number?

---@class SgEntry
---@field type "file" | "directory"
---@field data SgFile | SgDirectory

---@class SgDirectory
---@field remote string
---@field oid string
---@field path string
---@field bufname string

---@class SgFile
---@field remote string
---@field oid string
---@field path string
---@field bufname string
---@field position nil|SgPosition

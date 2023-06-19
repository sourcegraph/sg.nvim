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

---@class SourcegraphEmbedding
---@field type "Text"|"Code"
---@field repo string
---@field file string
---@field start number
---@field finish number
---@field content string

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

---@class CodyConfig
---@field tos_accepted boolean
---@field token string
---@field endpoint string

---@class CodyClientInfo
---@field name string
---@field version string
---@field workspaceRootPath string
---@field connectionConfiguration CodyConnectionConfiguration?
---@field capabilities CodyClientCapabilities?

---@class CodyConnectionConfiguration
---@field serverEndpoint string
---@field accessToken string
---@field customHeaders table<string, string>

---@class CodyClientCapabilities
---@field completions 'none'?
---@field chat 'none' | 'streaming' | nil

---@class CodyServerInfo
---@field name string
---@field authenticated boolean
---@field codyEnabled boolean
---@field codyVersion string?
---@field capabilities CodyServerCapabilities?

---@class CodyServerCapabilities

---@class CodyTextDocument
---@field filePath string
---@field content string?
---@field selection CodyRange?

---@class CodyPosition
---@field line number
--- 0-indexed
---@field character number
---  0-indexed

---@class CodyRange
---@field start CodyPosition
---@field end CodyPosition

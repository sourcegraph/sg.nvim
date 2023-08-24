local M = {}

---@class SgPosition
---@field line number?
---@field col number?

---@class SgEntry
---@field type "file" | "directory" | "repo"
---@field bufname string
---@field data SgFile | SgDirectory | SgRepo

---@class SgDirectory
---@field remote string
---@field oid string
---@field path string

---@class SgFile
---@field remote string
---@field oid string
---@field path string
---@field position nil|SgPosition

---@class SgRepo
---@field remote string
---@field oid string

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
---@field extensionConfiguration CodyExtensionConfiguration?
---@field capabilities CodyClientCapabilities?

---@class CodyExtensionConfiguration
---@field serverEndpoint string
---@field accessToken string
---@field codebase string?
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

---@class CodyContextFile
---@field fileName string
---@field repoName string?
---@field revision string?
---@field source string?

---@class CodyChatMessageData
---@field id string

---@class CodyChatMessage
---@field speaker string
---@field text string
---@field displayText string?
---@field contextFiles CodyContextFile[]?
---@field data CodyChatMessageData

---@class CodyChatUpdateMessageInProgressNoti: CodyChatMessage
---@field text string?
---@field data any?

---@alias CodyChatCallback fun(msg: CodyChatMessage)

---@class CodyAutocompleteItem
---@field insertText string
---@field range CodyRange

---@class CodyAutocompleteResult
---@field items CodyAutocompleteItem[]

---@class SourcegraphAuthConfig
---@field endpoint string: The sourcegraph endpoint
---@field token string: The sourcegraph auth token

---@enum SourcegraphAuthStrategy
M.auth_strategy = { app = "cody-app", nvim = "nvim", env = "environment-variables" }

---@class SourcegraphAuthObject
---@field doc string: Description
---@field get function(): SourcegraphAuthConfig?

---@class SgSearchResult
---@field repo string
---@field file string
---@field preview string
---@field line number

return M

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
---@field user string
---@field tos_accepted boolean
---@field token string
---@field endpoint string
---@field ignored_notifications table

---@class CodyClientInfo
---@field name string
---@field version string
---@field workspaceRootUri string
---@field extensionConfiguration CodyExtensionConfiguration?
---@field capabilities CodyClientCapabilities?

---@class CodyExtensionConfiguration
---@field serverEndpoint string
---@field accessToken string
---@field codebase string?
---@field customHeaders table<string, string>
---@field eventProperties CodyEventProperties
---@field autocompleteAdvancedProvider? string
---@field autocompleteAdvancedModel? string

---@class CodyEventProperties
---@field anonymousUserID string
---@field prefix string
---@field client string
---@field source string

---@class CodyClientCapabilities
---@field completions 'none'?
---@field chat 'none' | 'streaming' | nil

---@class CodyServerInfo
---@field name string?
---@field authenticated boolean?
---@field codyEnabled boolean?
---@field codyVersion string?
---@field capabilities CodyServerCapabilities?

---@class CodyServerCapabilities

---@class CodyTextDocument
---@field filePath string
---@field content string?
---@field selection cody.Range?

---@class cody.Position
---@field line number
--- 0-indexed
---@field character number
---  0-indexed

---@class cody.Range
---@field start cody.Position
---@field end cody.Position

---@class cody.URI
---@field authority string
---@field fragment string
---@field path string
---@field query string
---@field scheme string

---@class cody.ContextFile
---@field type string
---@field uri cody.URI
---@field range cody.Range
---@field repoName? string
---@field revision? string
---@field source? string
---@field content? string

---@class cody.ChatButton
--[[ TODO
export interface ChatButton {
    label: string
    action: string
    onClick: (action: string) => void
    appearance?: 'primary' | 'secondary' | 'icon'
}
--]]

---@enum cody.ChatEventSource: string
M.cchat_event_source = {
  ["chat"] = "chat",
  ["editor"] = "editor",
  ["menu"] = "menu",
  ["code-action"] = "code-action",
  ["custom-commands"] = "custom-commands",
  ["test"] = "test",
  ["code-lens"] = "code-lens",
  ["ask"] = "ask",
  ["doc"] = "doc",
  ["edit"] = "edit",
  ["explain"] = "explain",
  ["smell"] = "smell",
  ["reset"] = "reset",
}

---@class cody.ChatMetadata
---@field source? cody.ChatEventSource
---@field requestID? string
---@field chatModel? string

---@class cody.ChatError
---@field kind? string
---@field name string
---@field message string
-- Rate-limit properties
---@field retryAfter? string
---@field limit? number
---@field userMessage? string
---@field retryAfterDate? string
---@field retryAfterDateString? string
---@field retryMessage? string
---@field feature? string
---@field upgradeIsAvailable? boolean
-- Prevent Error from being passed as ChatError.
-- Errors should be converted using errorToChatError.
---@field isChatErrorGuard 'isChatErrorGuard'

---@enum cody.Speaker
M.CodySpeaker = { human = "human", assistant = "assistant" }

---@class cody.Message
---@field speaker cody.Speaker
---@field text? string

---@class cody.ChatMessage : cody.Message
---@field displayText? string
---@field contextFiles? cody.ContextFile[]
---@field preciseContext? cody.PreciseContext[]
---@field buttons? cody.ChatButton[]
---@field data? CodyChatMessageData
---@field metadata? cody.ChatMetadata
---@field error? cody.ChatError

---@class CodyChatMessageData

---@class cody.PreciseContext
--[[
export interface PreciseContext {
    symbol: {
        fuzzyName?: string
    }
    hoverText: string[]
    definitionSnippet: string
    filePath: string
    range?: {
        startLine: number
        startCharacter: number
        endLine: number
        endCharacter: number
    }
} ]]

---@class CodyChatUpdateMessageInProgressNoti: cody.ChatMessage
---@field text string?
---@field data any?

---@class CodyAutocompleteItem
---@field insertText string
---@field range cody.Range

---@class CodyAutocompleteResult
---@field items CodyAutocompleteItem[]

---@class SourcegraphAuthConfig
---@field endpoint string: The sourcegraph endpoint
---@field token string: The sourcegraph auth token

---@class SourcegraphAuthObject
---@field doc string: Description
---@field get function(): SourcegraphAuthConfig?

---@class SgSearchResult
---@field repo string
---@field file string
---@field preview string
---@field line number

---@enum Cody.ChatSubmitType
M.chat_submit_type = { user = "user", suggestion = "suggestion", example = "example" }

---@class cody.ExtensionTranscriptMessage
---@field type 'transcript'
---@field chatID string
---@field messages cody.ChatMessage[]
---@field isMessageInProgress boolean

---@class cody.ChatModelProvider
---@field codyProOnly boolean
---@field default boolean
---@field model string
---@field provider string
---@field title string

---@class cody.ExtensionMessage.config
---@field config table
---@field authStatus cody.AuthStatus

---@class cody.AuthStatus
---@field username string
---@field endpoint string?
---@field isDotCom boolean
---@field isLoggedIn boolean
---@field showInvalidAccessTokenError boolean
---@field authenticated boolean
---@field hasVerifiedEmail boolean
---@field requiresVerifiedEmail boolean
---@field siteHasCodyEnabled boolean
---@field siteVersion string
---@field configOverwrites? cody.CodyLLMSiteConfiguration
---@field showNetworkError? boolean
---@field primaryEmail string
---@field displayName? string
---@field avatarURL string
---@field userCanUpgrade boolean

---@class cody.CodyLLMSiteConfiguration
---@field chatModel? string
---@field chatModelMaxTokens? number
---@field fastChatModel? string
---@field fastChatModelMaxTokens? number
---@field completionModel? string
---@field completionModelMaxTokens? number
---@field provider? string

---@class cody.CurrentUserCodySubscription
---@field status cody.CodySubscriptionStatus
---@field plan cody.CodySubscriptionPlan
---@field applyProRateLimits boolean
---@field currentPeriodStartAt string
---@field currentPeriodEndAt string

---@enum cody.CodySubscriptionStatus
M.cody_subscription_status = {
  ACTIVE = "ACTIVE",
  PAST_DUE = "PAST_DUE",
  UNPAID = "UNPAID",
  CANCELED = "CANCELED",
  TRIALING = "TRIALING",
  PENDING = "PENDING",
  OTHER = "OTHER",
}

---@enum cody.CodySubscriptionPlan
M.cody_subscription_plan = {
  FREE = "FREE",
  PRO = "PRO",
}

return M

local log = require "sg.log"
local rpc = require "sg.cody.rpc"

local CodySpeaker = require("sg.types").CodySpeaker
local Mark = require "sg.mark"
local Message = require "sg.cody.message"
local Transcript = require "sg.cody.transcript"
local Typewriter = require "sg.components.typewriter"

---@class cody.ChatOpts
---@field id string: ID sent from cody-agent
---@field name? string

---@class cody.Chat
---@field id string: chat ID (from cody-agent)
---@field name string
---@field transcript sg.cody.Transcript
---@field models cody.ChatModelProvider[]
---@field windows table
---@field config cody.ExtensionMessage.config?
local Chat = {}
Chat.__index = Chat

--- Create a new state
---@param opts cody.ChatOpts
---@return cody.Chat
function Chat.init(opts)
  local windows = Chat._make_windows()

  local self = setmetatable({
    id = assert(opts.id, "[cody.state] must pass an ID"),
    name = opts.name or opts.id,
    windows = windows,
    transcript = nil,
    config = nil,
  }, Chat)

  self:_add_prompt_keymaps()

  return self
end

function Chat:_add_prompt_keymaps()
  local set = function(mode, key, cb)
    vim.keymap.set(mode, key, cb, { buffer = self.windows.prompt_bufnr })
  end

  -- stylua: ignore start
  set("i", "<CR>", function() self:complete() end)
  set({"i", "n"}, "<C-C>", function() self:close() end)
  -- stylua: ignore end

  set("n", "<space>m", function()
    rpc.request("chat/submitMessage", {
      id = self.id,
      message = {
        command = "chatModel",
        model = "openai/gpt-4-1106-preview",
      },
    }, function(err, data)
      print(vim.inspect { err = err, data = data })
    end)
  end)
end

function Chat:close()
  pcall(vim.api.nvim_win_close, self.windows.prompt_win, true)
  pcall(vim.api.nvim_win_close, self.windows.history_win, true)
  if self.windows.settings_win then
    pcall(vim.api.nvim_win_close, self.windows.settings_win, true)
  end
end

--- Add a new message and return its id
---@param message sg.cody.Message
function Chat:submit(message, callback)
  callback = callback or function() end
  -- require("sg.cody.rpc.chat").submit_message(self.id, message:to_submit_message(), callback)

  rpc.request(
    "chat/submitMessage",
    { id = self.id, message = message:to_submit_message() },
    callback
  )
end

--- Update the transcript
---@param transcript cody.ExtensionTranscriptMessage
function Chat:update_transcript(transcript)
  if not self.transcript then
    self.transcript = Transcript.of_agent_transcript(transcript)
  else
    self.transcript:update(transcript)
  end
end

--- Get a new completion, based on the state
function Chat:complete(callback)
  callback = callback or function() end
  local text = vim.api.nvim_buf_get_lines(self.windows.prompt_bufnr, 0, -1, false)
  vim.api.nvim_buf_set_lines(self.windows.prompt_bufnr, 0, -1, false, {})

  local message = Message.init(CodySpeaker.human, text)

  self:render()
  self:submit(message, function(err, data)
    callback(err, data)
  end)
end

--- Render the state to a buffer and window
function Chat:render()
  if not self.windows or not self.windows.prompt_bufnr then
    return
  end

  -- Think these are the right ones
  local bufnr = self.windows.history_bufnr
  local win = self.windows.history_win

  log.trace "chat:render"
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(win) then
    log.trace "chat:invalid buf"
    return
  end

  local lines = {}
  if self.windows.settings_bufnr then
    if self.transcript then
      if self.transcript:is_message_in_progress() then
        table.insert(lines, "status: In Progress")
      else
        table.insert(lines, "status: Complete")
      end
    else
      table.insert(lines, "status: Not Started")
    end

    if self.config then
      table.insert(
        lines,
        string.format("model: %s", self.config.authStatus.configOverwrites.chatModel)
      )
    end

    if self.models then
      vim.list_extend(lines, vim.split(vim.inspect(self.models), "\n"))
    end

    vim.api.nvim_buf_set_lines(self.windows.settings_bufnr, 0, -1, false, lines)
  end

  if not self.transcript then
    log.debug "chat:no-transcript"
    return
  end

  -- Keep track of how many messages have been rendered
  local rendered = 0

  --- Render a message
  ---@param idx number
  ---@param message_state sg.cody.transcript.MessageWrapper
  local render_one_message = function(idx, message_state)
    local message = message_state.message
    if message.hidden then
      return
    end

    if not message_state.mark or not message_state.mark:valid(bufnr) then
      -- Put a blank line between different marks
      if rendered >= 1 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "" })
      end

      -- Create a new extmark associated in the last line
      local last_line = vim.api.nvim_buf_line_count(bufnr) - 1
      message_state = self.transcript:set_mark(
        idx,
        Mark.init {
          ns = Typewriter.ns,
          bufnr = bufnr,
          start_row = last_line,
          start_col = 0,
          end_row = last_line,
          end_col = 0,
        }
      )
    end

    -- If the message has already been completed, then we can just display it immediately.
    --  This prevents typewriter from typing everything out all the time when you do something like
    --  toggle the previous chat
    local interval
    if not self.transcript:is_message_in_progress() then
      interval = 0
    end

    local text = vim.trim(table.concat(message:render(), "\n"))
    message_state.typewriter:set_text(text)
    message_state.typewriter:render(bufnr, win, message_state.mark, { interval = interval })

    rendered = rendered + 1
  end

  for i = 1, self.transcript:length() do
    render_one_message(i, self.transcript:get_message(i))
  end
end

function Chat:set_models(models)
  self.models = models
  self:render()
end

--- Set the config
function Chat:set_config(config)
  self.config = config
  self:render()
end

function Chat._make_windows()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)

  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2) - 2

  local prompt_height = 5
  local history_height = height - prompt_height

  local history_width = width
  local prompt_width = width
  local settings_width = 0

  if width > 50 then
    settings_width = 50
    prompt_width = width - settings_width - 2
    history_width = prompt_width
  end

  ---@type vim.api.keyset.float_config
  local history_opts = {
    relative = "editor",
    border = "rounded",
    width = history_width,
    height = history_height - 2,
    style = "minimal",
    row = row,
    col = col,
  }

  local history_bufnr = vim.api.nvim_create_buf(false, true)
  local history_win = vim.api.nvim_open_win(history_bufnr, true, history_opts)

  local prompt_opts = {
    relative = "editor",
    border = "rounded",
    width = prompt_width,
    height = prompt_height,
    style = "minimal",
    row = row + history_height,
    col = col,
  }

  local settings_win, settings_bufnr
  if settings_width > 0 then
    local settings_opts = {
      relative = "editor",
      border = "rounded",
      width = settings_width,
      height = prompt_height + history_height,
      style = "minimal",
      row = row,
      col = col + prompt_width + 2,
    }

    settings_bufnr = vim.api.nvim_create_buf(false, true)
    settings_win = vim.api.nvim_open_win(settings_bufnr, true, settings_opts)
  end

  local prompt_bufnr = vim.api.nvim_create_buf(false, true)
  local prompt_win = vim.api.nvim_open_win(prompt_bufnr, true, prompt_opts)

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = prompt_bufnr,
    once = true,
    callback = function()
      vim.api.nvim_win_close(prompt_win, true)
      vim.api.nvim_win_close(history_win, true)
      if settings_win then
        vim.api.nvim_win_close(settings_win, true)
      end
    end,
  })

  return {
    prompt_bufnr = prompt_bufnr,
    prompt_win = prompt_win,
    history_bufnr = history_bufnr,
    history_win = history_win,
    settings_bufnr = settings_bufnr,
    settings_win = settings_win,
  }
end

---@class Cody.ExtensionMessage

---@enum Cody.ChatWebviewMessage
-- local chat_webview_message = { ready = "ready", initialized = "initialized", submit = "submit" }
---= Cody.ChatWebviewMessage.ready | Cody.ChatWebviewMessage.initialized | Cody.ChatWebviewMessage.submit

---@class Cody.ChatWebviewMessage.submit
---@field command 'submit'
---@field text string
---@field submitType Cody.ChatSubmitType
---@field addEnhancedContext? boolean
---@field contextFiles? cody.ContextFile[]

local handlers = {}

-- export type ExtensionMessage =
--     | { type: 'config'; config: ConfigurationSubsetForWebview & LocalEnv; authStatus: AuthStatus }
--     | { type: 'history'; messages: UserLocalHistory | null }
--     | { type: 'transcript'; messages: ChatMessage[]; isMessageInProgress: boolean; chatID: string }
--     // TODO(dpc): Remove classic context status when enhanced context status encapsulates the same information.
--     | { type: 'contextStatus'; contextStatus: ChatContextStatus }
--     | { type: 'view'; messages: View }
--     | { type: 'errors'; errors: string }
--     | { type: 'suggestions'; suggestions: string[] }
--     | { type: 'notice'; notice: { key: string } }
--     | { type: 'custom-prompts'; prompts: [string, CodyCommand][] }
--     | { type: 'transcript-errors'; isTranscriptError: boolean }
--     | { type: 'userContextFiles'; context: ContextFile[] | null; kind?: ContextFileType }
--     | { type: 'chatModels'; models: ChatModelProvider[] }
--     | { type: 'update-search-results'; results: SearchPanelFile[]; query: string }
--     | { type: 'index-updated'; scopeDir: string }
--     | { type: 'enhanced-context'; context: EnhancedContextContextT }

---@class sg.cody.ChatState
---@field id string
---@field layout CodyLayoutSplit

---@type table<string, cody.Chat>
local chats = {}

--- Create a new chat session, an initialize UI for chat
---@param opts table
---@param callback? fun(err, data)
---@return fun(err: any?, id: string?)
handlers.make_chat = function(opts, callback)
  callback = callback or function() end

  return function(err, id)
    if err then
      vim.notify(err)
      return
    end

    opts = vim.deepcopy(opts)
    opts.id = id

    local chat = Chat.init(opts)
    chat:render()

    chats[id] = chat

    callback(err, id)
  end
end

-- // High-level wrapper around command/execute and  webview/create to start a
-- // new chat session.  Returns a UUID for the chat session.
-- 'chat/new': [null, string]
handlers.new = function(opts, callback)
  opts = opts or {}
  callback = callback or function() end

  rpc.request("chat/new", nil, handlers.make_chat(opts, callback))
end

--- Update the transcript for a chat session.
---@param id string
---@param transcript_message  cody.ExtensionTranscriptMessage
handlers.update_transcript = function(id, transcript_message)
  local chat = chats[id]
  if not chat then
    return
  end

  chat:update_transcript(transcript_message)
  chat:render()
end

--- Update models
---@param id string
---@param models cody.ChatModelProvider[]
handlers.set_models = function(id, models)
  local chat = chats[id]
  if not chat then
    return
  end

  chat:set_models(models)
  chat:render()
end

--- High-level wrapper around webview/receiveMessage and webview/postMessage
--- to submit a chat message. The ID is the return value of chat/id, and the
--- message is forwarded verbatim via webview/receiveMessage. This helper
--- abstracts over the low-level webview notifications so that you can await
--- on the request.  Subscribe to webview/postMessage to stream the reply
--- while awaiting on this response.
---
--- 'chat/submitMessage': [{ id: string; message: WebviewMessage }, ExtensionMessage]
---
---@param id any
---@param message Cody.ChatWebviewMessage.submit
---@param callback fun(err, data: Cody.ExtensionMessage)
handlers.submit_message = function(id, message, callback)
  callback = callback or function() end

  local layout = chats[id]
  if not layout then
    return
  end

  -- TODO: Couldn't get this to work yet. Need to hook up the IDs properly
  -- -- Add user and loading message premptively
  -- layout.state:append(Message.init(Speaker.user, vim.split(message.text or "", "\n"), {}))
  -- layout.state:append(Message.init(Speaker.cody, { "Loading ..." }, {}))
  -- layout:render()

  rpc.request("chat/submitMessage", { id = id, message = message }, callback)
end

handlers.config = function(id, config)
  local chat = chats[id]
  if not chat then
    return
  end

  chat:set_config(config)
end

handlers.models = function(id, callback)
  rpc.request("chat/models", { id = id }, callback)
end

-- We can't do this yet? it doesn't work with submitMessage
-- M.reset = function(id, callback)
--   callback = callback or function() end
--   rpc.request("chat/submitMessage", { id = id, message = { command = "reset" } }, callback)
-- end

return handlers

local keymaps = require "sg.keymaps"
local log = require "sg.log"
local rpc = require "sg.cody.rpc"
local shared = require "sg.components.shared"
local util = require "sg.utils"

local CodySpeaker = require("sg.types").CodySpeaker
local Mark = require "sg.mark"
local Message = require "sg.cody.message"
local Transcript = require "sg.cody.transcript"
local Typewriter = require "sg.components.typewriter"

---@type cody.Chat?
local last_chat = nil

---@alias cody.ChatKeymap fun(self: cody.Chat): nil
---@alias cody.ChatMapping { [1]: string, [2]: cody.ChatKeymap } | false

---@class cody.ChatOpts
---@field id? string: ID sent from cody-agent
---@field name? string
---@field model? string: The name of the model to set for the conversation
---@field interval? number: The interval (in ms) to send a message
---@field keymaps? table<string, table<string, cody.ChatMapping>>: Table of mode, key -> function
---@field window_type? "float" | "split" | "hover"
---@field window_opts? { width: number, height: number, split_cmd: string? }

---@class cody.ChatWindows
---@field prompt_bufnr number
---@field prompt_win number
---@field history_bufnr number
---@field history_win number
---@field settings_bufnr number?
---@field settings_win number?

---@class cody.Chat
---@field id string: chat ID (from cody-agent)
---@field name string
---@field transcript sg.cody.Transcript
---@field models cody.ChatModelProvider[]
---@field current_model string
---@field windows cody.ChatWindows
---@field config cody.ExtensionMessage.config?
---@field opts cody.ChatOpts
local Chat = {}
Chat.__index = Chat

--- Create a new state
---@param opts cody.ChatOpts
---@return cody.Chat
function Chat.init(opts)
  opts.window_type = opts.window_type or "float"
  if opts.window_type == "split" then
    opts.window_opts = opts.window_opts or { width = 0.4 }
  else
    opts.window_opts = opts.window_opts or { width = 0.9, height = 0.8 }
  end

  local windows = Chat._make_windows(opts)

  local self = setmetatable({
    id = assert(opts.id, "[cody.state] must pass an ID"),
    name = opts.name or opts.id,
    opts = opts,
    windows = windows,
    current_model = nil,
    transcript = nil,
    config = nil,
  }, Chat)

  self:_add_prompt_keymaps()

  return self
end

function Chat:reopen()
  local windows = Chat._make_windows(self.opts)
  self.windows = windows

  self:_add_prompt_keymaps()
  self:render()

  return self
end

function Chat:_add_prompt_keymaps()
  local bufnr = self.windows.prompt_bufnr
  local history = self.windows.history_bufnr

  keymaps.map(bufnr, "n", "<CR>", "Submit Message", function()
    self:complete()
  end)

  keymaps.map(bufnr, "i", "<C-CR>", "Submit Message", function()
    self:complete()
  end)

  keymaps.map({ bufnr, history }, { "i", "n" }, "<c-c>", "Quit Chat", function()
    self:close()
  end)

  keymaps.map({ bufnr, history }, "n", "<c-t>", "Toggle Focus", function()
    if vim.api.nvim_get_current_win() == self.windows.history_win then
      vim.api.nvim_set_current_win(self.windows.prompt_win)
    else
      vim.api.nvim_set_current_win(self.windows.history_win)
    end
  end)

  local with_history = function(key, mapped)
    if not mapped then
      mapped = key
    end

    local desc = "Execute '" .. key .. "' in history"
    keymaps.map(bufnr, { "n", "i" }, key, desc, function()
      if vim.api.nvim_win_is_valid(self.windows.history_win) then
        vim.api.nvim_win_call(self.windows.history_win, function()
          util.execute_keystrokes(mapped)
        end)
      end
    end)
  end

  with_history "<c-f>"
  with_history "<c-b>"
  with_history "<c-e>"
  with_history "<c-y>"

  keymaps.map(bufnr, "n", "M", "Select Model", function()
    require("sg.cody.rpc.chat").models(self.id, function(err, data)
      if err then
        return
      end

      ---@type cody.ChatModelProvider[]
      local models = data.models or {}
      vim.ui.select(models, {
        prompt = "Select a model for conversation",

        --- Format an item
        ---@param item cody.ChatModelProvider
        format_item = function(item)
          return item.model
        end,
      }, function(choice)
        rpc.request("webview/receiveMessage", {
          id = self.id,
          message = {
            command = "chatModel",
            model = choice.model,
          },
        }, function()
          self:set_current_model(choice.model)
          self:render()
        end)
      end)
    end)
  end)

  keymaps.map(bufnr, "n", "?", "Show Keymaps", function()
    keymaps.help(bufnr)
  end)

  local keymap_overrides = self.opts.keymaps or {}
  for mode, overrides in pairs(keymap_overrides) do
    for key, value in pairs(overrides) do
      if value then
        local desc, func = unpack(value)
        keymaps.map(bufnr, mode, key, desc, function()
          func(self)
        end)
      else
        keymaps.del(bufnr, mode, key)
      end
    end
  end

  -- TODO: Need to write a bit more stuff to manage this
  -- keymaps.map(bufnr, "n", "<space>m", function()
  --   rpc.request("webview/receiveMessage", {
  --     id = self.id,
  --     message = {
  --       command = "chatModel",
  --       model = "openai/gpt-4-1106-preview",
  --     },
  --   }, function(err, data)
  --     self:set_current_model "openai/gpt-4-1106-preview"
  --     self:render()
  --   end)
  -- end)
end

function Chat:set_current_model(model)
  self.current_model = model
end

function Chat:close()
  pcall(vim.api.nvim_win_close, self.windows.prompt_win, true)
  pcall(vim.api.nvim_win_close, self.windows.history_win, true)
  if self.windows.settings_win then
    pcall(vim.api.nvim_win_close, self.windows.settings_win, true)
  end

  pcall(vim.api.nvim_buf_delete, self.windows.prompt_bufnr)
end

--- Add a new message and return its id
---@param message sg.cody.Message
function Chat:submit(message, callback)
  callback = callback or function() end

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
  if not self.windows or not self.windows.history_win then
    return
  end

  last_chat = self

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
    local status_fmt = "Status    : %s"
    local model_fmt = "Chat Model: %s"

    if self.transcript then
      if self.transcript:is_message_in_progress() then
        table.insert(lines, string.format(status_fmt, "In Progress"))
      else
        table.insert(lines, string.format(status_fmt, "Complete"))
      end
    else
      table.insert(lines, string.format(status_fmt, "Not Started"))
    end

    if self.current_model then
      table.insert(lines, string.format(model_fmt, self.current_model))
    elseif self.models then
      ---@type cody.ChatModelProvider
      local default = vim.tbl_filter(function(model)
        return model.default
      end, self.models)[1]

      table.insert(lines, string.format(model_fmt, default.model))
    elseif self.config then
      table.insert(
        lines,
        string.format(model_fmt, self.config.authStatus.configOverwrites.chatModel)
      )
    end

    if self.transcript then
      -- Had some weird errors here
      pcall(function()
        table.insert(lines, "")
        table.insert(lines, "Context Files:")
        table.insert(lines, "")
        for _, context_file in ipairs(self.transcript:context_files()) do
          local range = context_file.range
          local start = range.start

          table.insert(
            lines,
            string.format(
              "%s:%s:%s",
              vim.fn.fnamemodify(context_file.uri.path, ":."),
              start.line,
              start.character
            )
          )
        end
      end)
    end

    -- Add keymaps
    table.insert(lines, "")
    table.insert(lines, "Cody Keymaps:")
    vim.list_extend(lines, keymaps.help_lines(self.windows.prompt_bufnr))

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
    local interval = self.opts.interval
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
  self.models = models.models
  self:render()
end

--- Set the config
function Chat:set_config(config)
  self.config = config
  self:render()
end

---@param opts cody.ChatOpts
function Chat._make_windows(opts)
  local win_opts = opts.window_opts
  if opts.window_type == "float" then
    local width = shared.calculate_width(win_opts.width)
    local height = shared.calculate_height(win_opts.height)

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

    shared.make_buf_minimal(history_bufnr)
    shared.make_win_minimal(history_win)
    vim.bo[history_bufnr].filetype = opts.filetype or "markdown.cody_prompt"

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

      shared.make_buf_minimal(settings_bufnr)
      shared.make_win_minimal(settings_win)

      vim.wo[settings_win].wrap = false
    end

    local prompt_bufnr = vim.api.nvim_create_buf(false, true)
    local prompt_win = vim.api.nvim_open_win(prompt_bufnr, true, prompt_opts)
    shared.make_buf_minimal(prompt_bufnr)
    shared.make_win_minimal(prompt_win)

    vim.api.nvim_create_autocmd({ "BufDelete", "BufHidden" }, {
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
  elseif opts.window_type == "split" then
    vim.cmd(win_opts.split_cmd or "botright vnew")

    local history_win = vim.api.nvim_get_current_win()
    local history_bufnr = vim.api.nvim_get_current_buf()

    local width = shared.calculate_width(win_opts.width)
    vim.api.nvim_win_set_width(history_win, width)

    shared.make_win_minimal(history_win)
    shared.make_buf_minimal(history_bufnr)
    vim.bo[history_bufnr].filetype = opts.filetype or "markdown.cody_prompt"

    vim.wo[history_win].winbar = "%=Cody History%="

    vim.cmd(win_opts.split_cmd or "below new")
    local prompt_win = vim.api.nvim_get_current_win()
    local prompt_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_win_set_height(prompt_win, 6)
    shared.make_win_minimal(prompt_win)
    shared.make_buf_minimal(prompt_bufnr)

    vim.wo[prompt_win].winbar = "Cody Prompt%=%#Comment#(`?` for help)"

    return {
      prompt_bufnr = prompt_bufnr,
      prompt_win = prompt_win,
      history_bufnr = history_bufnr,
      history_win = history_win,
      settings_bufnr = nil,
      settings_win = nil,
    }
  elseif opts.window_type == "hover" then
    local width = shared.calculate_width(win_opts.width)
    local height = shared.calculate_height(win_opts.height)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2) - 2

    local history_height = height
    local history_width = width

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

    shared.make_buf_minimal(history_bufnr)
    shared.make_win_minimal(history_win)
    vim.bo[history_bufnr].filetype = opts.filetype or "markdown.cody_prompt"

    vim.api.nvim_create_autocmd({ "BufDelete", "BufHidden" }, {
      buffer = history_bufnr,
      once = true,
      callback = function()
        vim.api.nvim_win_close(history_win, true)
      end,
    })

    return {
      prompt_bufnr = nil,
      prompt_win = nil,
      history_bufnr = history_bufnr,
      history_win = history_win,
      settings_bufnr = nil,
      settings_win = nil,
    }
  else
    error(string.format("Unknown window type: %s", opts.window_type))
  end
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

handlers.open_or_new = function(opts, callback)
  if last_chat then
    last_chat:reopen()
  else
    handlers.new(opts, callback)
  end
end

handlers.toggle = function(_)
  if last_chat then
    if vim.api.nvim_win_is_valid(last_chat.windows.history_win) then
      last_chat:close()
    else
      last_chat:reopen()
    end
  else
    handlers.new()
  end
end

--- High-level wrapper around command/execute and  webview/create to start a
--- new chat session.  Returns a UUID for the chat session.
--- 'chat/new': [null, string]
---@param opts? cody.ChatOpts
---@param callback? fun(err, data)
---@return fun(err: any?, id: string?)
handlers.new = function(opts, callback)
  callback = callback or function(err)
    if err then
      vim.notify(err)
    end
  end

  opts = opts or {}
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
---@param callback? fun(err, data: Cody.ExtensionMessage)
handlers.submit_message = function(id, message, callback)
  callback = callback or function() end

  local layout = chats[id]
  if not layout then
    return
  end

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

--- Get the last chat, if available
---@return cody.Chat?
handlers.get_last_chat = function()
  return last_chat
end

--- Get a chat
---@param id string
---@return cody.Chat?
handlers.get_chat = function(id)
  return chats[id]
end

return handlers

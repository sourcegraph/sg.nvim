local rpc = require "sg.rpc"
local async_system = require("sg.utils").async_system

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"

-- TODO: Should find the git root instead of just the current dir to save a bunch of requests
local repository_ids = {}

local context = {}

context.get_origin = function(bufnr)
  local dir = vim.api.nvim_buf_get_name(bufnr)
  dir = vim.fn.fnamemodify(dir, ":p:h")

  -- git remote get-url origin
  local obj = async_system({ "git", "remote", "get-url", "origin" }, {
    cwd = dir,
    text = true,
  })

  local origin = vim.trim(obj.stdout)
  origin = origin:gsub("^https://", "")
  origin = origin:gsub("^http://", "")

  return origin
end

context.get_repo_id = function(bufnr)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not repository_ids[bufnr] then
    local origin = context.get_origin(bufnr)
    local repository = rpc.repository(origin)
    repository_ids[bufnr] = repository
  end

  return repository_ids[bufnr]
end

--- Get the embeddings for a {repo} with {query}
---@param repo string
---@param query string
---@param opts { only: string, code?: number, text?: number}
---@return string?
---@return SourcegraphEmbedding[]
context.embeddings = function(repo, query, opts)
  opts = opts or {}

  local err, proto_embeddings = rpc.embeddings(repo, query, { code = opts.code, text = opts.text })
  if err ~= nil or proto_embeddings == nil then
    return err, {}
  end

  local only = opts.only

  local embeddings = {}
  if not only or only == "Text" then
    for _, enum_embed in ipairs(proto_embeddings) do
      if enum_embed.Text then
        local embed = enum_embed.Text
        embed.type = "Text"
        table.insert(embeddings, embed)
      end
    end
  end

  if not only or only == "Code" then
    for _, enum_embed in ipairs(proto_embeddings) do
      if enum_embed.Code then
        local embed = enum_embed.Code
        embed.type = "Code"
        table.insert(embeddings, embed)
      end
    end
  end

  return nil, embeddings
end

--- Add context to an existing state
---@param bufnr number
---@param text string
---@param state CodyState
context.add_context = function(bufnr, text, state)
  local repo = context.get_repo_id(bufnr)
  local _, embeddings = context.embeddings(repo, text, { only = "Code" })

  if vim.tbl_isempty(embeddings) then
    return
  end

  state:append(Message.init(Speaker.user, { "Here is some context" }, {}, { hidden = true }))
  for _, embed in ipairs(embeddings) do
    state:append(Message.init(Speaker.user, vim.split(embed.content, "\n"), {}, { hidden = true }))
  end
end

return context

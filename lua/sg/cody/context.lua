local rpc = require "sg.rpc"
local system = require "sg.system"

local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"

-- TODO: Should find the git root instead of just the current dir to save a bunch of requests
local repository_ids = {}

local context = {}
local get_origin = function(bufnr)
  local dir = vim.api.nvim_buf_get_name(bufnr)
  dir = vim.fn.fnamemodify(dir, ":p:h")

  -- git remote get-url origin
  local obj = system.async({ "git", "remote", "get-url", "origin" }, {
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
    local origin = get_origin(bufnr)
    local repository = rpc.repository(origin)
    repository_ids[bufnr] = repository
  end

  return repository_ids[bufnr]
end

---comment
---@param repo string
---@param query string
---@param only string?
---@return SourcegraphEmbedding[]
context.embeddings = function(repo, query, only)
  local proto_embeddings = rpc.embeddings(repo, query, {})

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

  return embeddings
end

--- Add context to an existing state
---@param bufnr number
---@param text string
---@param state CodyState
context.add_context = function(bufnr, text, state)
  local repo = context.get_repo_id(bufnr)
  local embeddings = context.embeddings(repo, text, "Code")

  if vim.tbl_isempty(embeddings) then
    return
  end

  state:append(Message.init(Speaker.user, { "Here is some context" }, { hidden = true }))
  for _, embed in ipairs(embeddings) do
    state:append(Message.init(Speaker.user, vim.split(embed.content, "\n"), { hidden = true }))
  end
end

return context

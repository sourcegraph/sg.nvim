```lua
--- Add context to an existing state
---@param bufnr number
---@param text string
---@param state CodyState
context.add_context = function(bufnr, text, state)
  local repo = context.get_repo_id(bufnr)
  if not repo then
    return
  end
  local _, embeddings = context.embeddings(repo, text, { only = "Code" })

  if vim.tbl_isempty(embeddings) then
    return
  end

  state:append(Message.init(Speaker.user, { "Here is some context" }, {}, { hidden = true }))
  for _, embed in ipairs(embeddings) do
    state:append(Message.init(Speaker.user, vim.split(embed.content, "\n"), {}, { hidden = true }))
  end
end
```

```lua
---@return string|nil
context.get_repo_id = function(bufnr)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local origin = context.get_origin(bufnr)
  if not origin then
    return nil
  end

  if not repository_ids[bufnr] then
    local repository = rpc.repository(origin)
    repository_ids[bufnr] = repository
  end

  return repository_ids[bufnr]
end

```

```lua

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

```

```lua
commands.recipes = function(bufnr, start_line, end_line)
  local selection = nil
  if start_line and end_line then
    selection = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  end

  local formatted = require("sg.utils").format_code(bufnr, selection)
  vim.print(formatted)

  local prompt =
    "You are an expert software developer and skilled communicator. Create a docstring for the following code. Make sure to document that functions purpose as well as any arguments."
  prompt = prompt .. "\n"
  prompt = prompt .. table.concat(formatted, "\n")
  prompt = prompt
    .. [[

Reply with JSON that meets the following specification:

interface Parameter {
  name: string
  type: string
  description: string
}

interface Docstring {
  function_description: string
  parameters: Parameter[]
}

If there are no parameters, just return an empty list.
]]

  local prefix = [[{"function_description":"]]

  void(function()
    print "Running completion..."
    local err, completed = require("sg.rpc").complete(prompt, { prefix = prefix, temperature = 0.1 })
    if err ~= nil then
      print "Failed to get completion"
      return
    end

    local ok, parsed = pcall(vim.json.decode, completed)
    if not ok then
      ok, parsed = pcall(vim.json.decode, prefix .. completed)
      if not ok then
        print "need to ask again... :'("
        print(completed)
        return
      end
    end

    if not parsed then
      print "did not send docstring"
      return
    end

    local lines = {}
    table.insert(lines, string.format("--- %s", parsed.function_description))
    table.insert(lines, "---")
    for _, param in ipairs(parsed.parameters) do
      table.insert(lines, string.format("---@param %s %s: %s", param.name, param.type, param.description))
    end

    vim.api.nvim_buf_set_lines(0, start_line, start_line, false, lines)
  end)()
end
```

```lua
--- Get embeddings for the a repo & associated query.
---@param repo string: Repo name (github.com/neovim/neovim)
---@param query any: query string (the question you want to ask)
---@param opts table: `code`: number of code results, `text`: number of text results
---@return string?: err, if any
---@return table?: list of embeddings
function rpc.embeddings(repo, query, opts)
  opts = opts or {}
  opts.code = opts.code or 5
  opts.text = opts.text or 0

  local err, repo_id = rpc.repository(repo)
  if err then
    return err, nil
  end

  local embedding_err, data = req("Embedding", {
    repo = repo_id,
    query = query,
    code = opts.code,
    text = opts.text,
  })
  if not embedding_err then
    return nil, data.embeddings
  else
    return embedding_err, nil
  end
end
```

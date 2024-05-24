--[[

NOTE: Do not require from this file to any other SG files.
      This makes sure that this can be required without
      anything else being built and/or linked up.

--]]
local utils = {}

utils.once = function(f)
  local value, called = nil, false
  return function(...)
    if not called then
      value = f(...)
      called = true
    end

    return value
  end
end

utils.get_word_around_character = function(line, character)
  local match_pat = "[^%w_]"
  local reversed = string.reverse(line)

  local reversed_starting_index = string.find(reversed, match_pat, #line - character, false)
  local start_non_matching_index
  if not reversed_starting_index then
    start_non_matching_index = 0
  else
    start_non_matching_index = #line - reversed_starting_index + 1
  end

  local end_non_matching_index = string.find(line, match_pat, character, false) or (#line + 1)
  return string.sub(line, start_non_matching_index + 1, end_non_matching_index - 1)
end

--- Format some code based on the filetype
---@param bufnr number
---@param code string|string[]
---@return table
utils.format_code = function(bufnr, code)
  return vim.tbl_flatten { string.format("```%s", vim.bo[bufnr].filetype), code, "```" }
end

utils.execute_keystrokes = function(keys)
  vim.cmd(string.format("normal! %s", vim.api.nvim_replace_termcodes(keys, true, false, true)))
end

-- COMPAT(0.10.0)
utils.joinpath = vim.fs.joinpath
  or function(...)
    return (table.concat({ ... }, "/"):gsub("//+", "/"))
  end

-- COMPAT(0.10.0)
-- So far only handle stdout, no other items are handled.
-- Probably will break on me unexpectedly. Nice
utils.system = vim.system or (require "sg.vendored.vim-system")

utils.open = function(...)
  local open = vim.ui.open
    or function(path)
      vim.validate {
        path = { path, "string" },
      }
      local is_uri = path:match "%w+:"
      if not is_uri then
        path = vim.fn.expand(path)
      end

      local cmd

      if vim.fn.has "mac" == 1 then
        cmd = { "open", path }
      elseif vim.fn.has "win32" == 1 then
        if vim.fn.executable "rundll32" == 1 then
          cmd = { "rundll32", "url.dll,FileProtocolHandler", path }
        else
          return nil, "vim.ui.open: rundll32 not found"
        end
      elseif vim.fn.executable "wslview" == 1 then
        cmd = { "wslview", path }
      elseif vim.fn.executable "xdg-open" == 1 then
        cmd = { "xdg-open", path }
      else
        return nil, "vim.ui.open: no handler found (tried: wslview, xdg-open)"
      end

      local rv = utils.system(cmd, { text = true, detach = true }):wait()
      if rv.code ~= 0 then
        local msg = ("vim.ui.open: command failed (%d): %s"):format(rv.code, vim.inspect(cmd))
        return rv, msg
      end

      return rv, nil
    end

  open(...)
end

-- From https://gist.github.com/jrus/3197011
utils.uuid = function()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Read a file and parse it as json, or return nil
---@param file string: The name of the file
---@return any
utils.json_or_nil = function(file)
  local handle = io.open(file)
  if handle then
    local contents = handle:read "*a"
    handle:close()

    local ok, parsed = pcall(vim.json.decode, contents)
    if ok and parsed then
      return parsed
    end
  end

  return nil
end

utils.valid_node_executable = function(executable)
  if 1 ~= vim.fn.executable(executable) then
    return false, string.format("invalid executable: %s", executable)
  end

  local output = vim.fn.systemlist(executable .. " --version") or {}
  -- systemlist() leaves CR behind on Windows, fixing inconsistency
  for i = #output, 1, -1 do
    output[i] = output[i]:gsub("\r$", "")
  end
  return utils._validate_node_output(output)
end

utils._validate_node_output = function(output)
  for _, line in ipairs(output) do
    local ok, version = pcall(vim.version.parse, line, { strict = true })
    if not ok then
      return false, string.format("invalid node version: %s", output)
    end

    -- Sometimes there is other garbage in the lines, so let's keep reading
    -- until we find something that looks like a version.
    --
    -- Only then will we check if it's valid
    if version then
      local min_node_version = assert(vim.version.parse "v18")
      if not vim.version.gt(version, min_node_version) then
        return false,
          string.format("node version must be >= %s. Got: %s", min_node_version, version)
      end

      return true, version
    end
  end

  return false, string.format("unable to determine node version: %s", vim.inspect(output))
end

utils.blocking = function(req, timeout)
  local results
  req(function(...)
    results = { ... }
  end)

  vim.wait(timeout or 10000, function()
    return results
  end, 10)

  return unpack(results or {})
end

utils.replace_markdown_link = function(str)
  return str:gsub("%[([^%]]+)%]%([^%)]+%)", function(text)
    return string.format("[%s]()", text)
  end)
end

--- Start the LSP server, compatible with nvim 0.9 still
---@param cmd string[]: Command to start the LSP server.
---@param dispatchers? vim.lsp.rpc.Dispatchers
---@param extra_spawn_params? vim.lsp.rpc.ExtraSpawnParams
---@return vim.lsp.rpc.PublicClient
utils.rpc_start = function(cmd, dispatchers, extra_spawn_params)
  local version = vim.version()
  if version.major == 0 and version.minor >= 10 then
    return vim.lsp.rpc.start(cmd, dispatchers, extra_spawn_params)
  else
    local executable = table.remove(cmd, 1)

    -- Compatbility line
    ---@diagnostic disable-next-line: redundant-parameter, param-type-mismatch
    return vim.lsp.rpc.start(executable, cmd, dispatchers, extra_spawn_params)
  end
end

return utils

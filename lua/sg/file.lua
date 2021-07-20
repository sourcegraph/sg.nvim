local Job = require "plenary.job"

local once = require("sg.utils").once
local cli = require "sg.cli"

local file = {}

file.read = function(remote, hash, path)
  local query = string.format("repo:^%s$", remote)
  if hash then
    query = query .. string.format("@%s", hash)
  end
  query = query .. string.format(" file:^%s$", path)

  vim.schedule(function()
    print(query)
  end)

  local output = cli.search(query)
  if not output.Results then
    error("no results: " .. vim.inspect(output))
  end

  local first = output.Results[1]
  if not first then
    error("no first: " .. vim.inspect(output))
  end

  if not first.file then
    error("no file: " .. vim.inspect(first))
  end

  return first.file.content
end

return file

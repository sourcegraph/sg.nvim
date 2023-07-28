local void = require("plenary.async").void
local jsonify = require "sg.cody.experimental.jsonify"

local interface = [[
interface Parameter {
  name: string
  type: string
  description: string
}

interface Docstring {
  function_description: string
  parameters: Parameter[]
} ]]

local selection = [[
local greet = function(name)
  print("Hello", name)
end
]]

void(function()
  local err, data = jsonify.async_execute {
    prompt_toplevel = "Create a docstring for the following code (If there are no arguments, include an empty list).",
    selection = selection,
    interface = interface,
    response_prefix = [[{"function_description":"]],
  }

  if err ~= nil then
    error("Oh no, we got an error" .. vim.inspect(err))
  end

  print("GOT DATA:", vim.inspect(data))
end)()

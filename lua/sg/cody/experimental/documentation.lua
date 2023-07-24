local jsonify = require "sg.cody.experimental.jsonify"

local M = {}

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

---@alias CodyUserDocumentationFormatter function(bufnr: number, parsed: CodyUserDocumentation_): string

---@type table<string, CodyUserDocumentationFormatter>
local builtin_formatters = {
  lua = function(_, parsed)
    local lines = {}
    table.insert(lines, string.format("--- %s", parsed.function_description))
    table.insert(lines, "---")
    for _, param in ipairs(parsed.parameters) do
      table.insert(lines, string.format("---@param %s %s: %s", param.name, param.type, param.description))
    end

    return lines
  end,
}

--- Select a region of text and then have Cody document it.
---@param bufnr number: Buffer to run in
---@param start_line number: Start line
---@param end_line number: End line
---@param formatter CodyUserDocumentationFormatter?
M.function_documentation = function(bufnr, start_line, end_line, formatter)
  if not formatter then
    formatter = builtin_formatters[vim.bo[bufnr].filetype]
  end

  if not formatter then
    error "Expected formatter. Either provide one or create a default one for your language"
  end

  local selection = table.concat(vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false), "\n")

  jsonify.execute({
    prompt_toplevel = "Create a docstring for the following code (If there are no arguments, include an empty list).",
    selection = selection,
    interface = interface,
    response_prefix = [[{"function_description":"]],
  }, function(err, parsed)
    if err ~= nil then
      error("Oh no, we got an error" .. vim.inspect(err))
    end

    local lines = formatter(bufnr, parsed)
    vim.api.nvim_buf_set_lines(bufnr, start_line, start_line, false, lines)
  end)
end

return M

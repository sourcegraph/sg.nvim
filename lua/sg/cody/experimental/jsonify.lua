if true then
  error "NOT YET FIXED, NEED TO DO ASYNC"
end

local void = require("plenary.async").void
local wrap = require("plenary.async").wrap

local utils = require "sg.utils"

local M = {}

-- TODO: Would be nice to be able to add a hook for additional context

---@class CodyUserJsonifyOpts
---@field prompt_toplevel string: The prompt to explain what you want cody to do
---@field interface string: The interface to respond with (use Typescript to describe)
---@field response_prefix string: The start of the JSON message,
---                    to force response in JSON (usually first field)
---@field bufnr number?: The current buffer you're in
---@field selection string?: Optional current selection
---@field temperature number?: The temperature to send to cody

--- Create a new jsonified query
---@param opts CodyUserJsonifyOpts: Options to create a jsonify object
---@param cb function(err: any, val: any): Function to call once request is completed
M.execute = function(opts, cb)
  assert(opts.prompt_toplevel, "must have toplevel prompt")
  assert(opts.response_prefix, "must have a prefix")

  opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  opts.temperature = opts.temperature or 0.1

  local prompt = opts.prompt_toplevel
  if opts.selection then
    prompt = prompt .. "\n" .. table.concat(utils.format_code(opts.bufnr, opts.selection), "\n")
  end

  prompt = prompt .. "Reply with JSON that meets the following specification:\n"
  prompt = prompt .. opts.interface .. "\n"

  void(function()
    local err, completed = require("sg.rpc").complete(prompt, { prefix = opts.response_prefix, temperature = 0.1 })
    if err ~= nil then
      return cb({ failure = "sg.rpc.complete", err = err }, nil)
    end

    local ok, parsed = pcall(vim.json.decode, completed)
    if not ok then
      ok, parsed = pcall(vim.json.decode, opts.response_prefix .. completed)
      if not ok then
        -- TODO: Should do a few retries automatically, to see if that can fix the problem
        return cb({ failure = "parsing response", err = parsed }, nil)
      end
    end

    if not parsed then
      -- TODO: Not sure what makes the most sense for this.
      return cb({ feailture = "parsed response", err = "There was no response to jsonify request" }, nil)
    end

    cb(nil, parsed)
  end)()
end

--- Asynchronous version of execute.
---@return any?: The error, if any
---@return any?: The data, if successful
M.async_execute = wrap(M.execute, 2)

return M

local void = require("plenary.async").void

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
---@param cb function(val: any): Function to call once request is completed
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
    print "Running completion..."
    local err, completed = require("sg.rpc").complete(prompt, { prefix = opts.response_prefix, temperature = 0.1 })
    if err ~= nil then
      print("ERROR: ", err)
      return
    end

    local ok, parsed = pcall(vim.json.decode, completed)
    if not ok then
      ok, parsed = pcall(vim.json.decode, opts.response_prefix .. completed)
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

    cb(parsed)
  end)()
end

return M

local uv = vim.loop
local sg_cody_process = "./target/debug/sg-cody"

local log = require "sg.log"

local M = {}

M.pending = {}
M.shutdown = function() end

local _id = 0
local get_next_id = function()
  _id = _id + 1
  return _id
end

-- Process vars, could be encapsulated some other way, but this is fine for now.
local handle, stdin, stdout, stderr = nil, nil, nil, nil
M.start = function(force)
  -- Debugging usefulness
  if force or handle == nil then
    M.shutdown()

    stdin = assert(uv.new_pipe())
    stdout = assert(uv.new_pipe())
    stderr = assert(uv.new_pipe())

    handle, _ = uv.spawn(sg_cody_process, {
      stdio = { stdin, stdout, stderr },
      env = {
        "SRC_ACCESS_TOKEN=" .. vim.env.SRC_ACCESS_TOKEN,
        "SRC_ENDPOINT=" .. vim.env.SRC_ENDPOINT,
      },
    }, function(code, signal) -- on exit
      if code ~= 0 then
        log.warn("[cody] exit code", code)
        log.warn("[cody] exit signal", signal)
      end
    end)

    local buffer = ""
    stdout:read_start(vim.schedule_wrap(function(err, data)
      assert(not err, err)
      if data then
        if vim.endswith(data, "\n") then
          for idx, line in ipairs(vim.split(data, "\n")) do
            if idx == 1 then
              line = buffer .. line
            end

            if line ~= "" then
              local ok, parsed = pcall(vim.json.decode, line, { luanil = { object = true } })
              if ok and parsed then
                log.info("stdout chunk", parsed)

                if M.pending[parsed.id] then
                  M.pending[parsed.id](parsed)
                  M.pending[parsed.id] = nil
                end
              else
                log.info("failed chunk", parsed)
              end
            else
              log.info "empty line"
            end
          end

          buffer = ""
        else
          local lines = vim.split(data, "\n")

          -- iterate over complete lines
          for i = 1, (#lines - 1) do
            local line = lines[i]
            if i == 1 then
              line = buffer .. line
              buffer = ""
            end

            log.info("chunked", i, vim.json.decode(lines[i]))
          end

          buffer = buffer .. lines[#lines]
          log.info("unchunked... for now!", buffer)
        end
      end
    end))

    stderr:read_start(vim.schedule_wrap(function(err, data)
      if err or data then
        warn("[cody] stderr:", err, data)
      end
    end))

    M.shutdown = function()
      uv.shutdown(stdin, function()
        if handle then
          uv.close(handle, function() end)
        end
      end)
    end

    vim.api.nvim_create_autocmd("ExitPre", {
      callback = M.shutdown,
    })
  end
end

M.request = function(method, data, cb)
  -- Ensure that we've started a process running
  M.start(false)

  local message = vim.deepcopy(data)
  message.id = get_next_id()
  message.method = method

  M.pending[message.id] = cb

  local encoded = vim.json.encode(message)
  log.info("sending message:", encoded)
  stdin:write(encoded .. "\n")
end

M.async_request = require("plenary.async").wrap(M.request, 3)

return M

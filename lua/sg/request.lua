local sg_cody_process = vim.api.nvim_get_runtime_file("target/debug/sg-cody", false)[1]
if not sg_cody_process then
  error "Could not find sg-cody binary. Make sure you ran `cargo build --bin sg-cody`"
end

local uv = vim.loop

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
local handle, pid, stdin, stdout, stderr = nil, nil, nil, nil, nil
M.start = function(force)
  -- Debugging usefulness
  if force or handle == nil then
    M.shutdown()

    stdin = assert(uv.new_pipe())
    stdout = assert(uv.new_pipe())
    stderr = assert(uv.new_pipe())

    handle, pid = uv.spawn(sg_cody_process, {
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

    if not handle then
      error(string.format("Failed to start process: %s", pid))
    end

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
                log.trace("stdout chunk", parsed)

                if M.pending[parsed.id] then
                  M.pending[parsed.id](parsed)
                  M.pending[parsed.id] = nil
                end
              else
                log.trace("failed chunk", parsed)
              end
            else
              log.trace "empty line"
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

            log.trace("chunked", i, vim.json.decode(lines[i]))
          end

          buffer = buffer .. lines[#lines]
          log.trace("unchunked... for now!", buffer)
        end
      end
    end))

    stderr:read_start(vim.schedule_wrap(function(err, data)
      if err or data then
        log.info("[cody] ", err, data)
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

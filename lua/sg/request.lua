local env = require "sg.env"
local log = require "sg.log"

local uv = vim.loop

---@type string
local bin_sg_cody = (function()
  local cmd = "sg-cody"
  if vim.fn.executable(cmd) == 1 then
    return cmd
  end

  local cmd_paths = {
    "target/release/sg-cody",
    "target/debug/sg-cody",
    "bin/sg-cody",
  }
  for _, path in ipairs(cmd_paths) do
    local res = vim.api.nvim_get_runtime_file(path, false)[1]
    if res then
      return res
    end
  end

  error "Failed to load sg-cody: You probably did not run `nvim -l build/init.lua`"
end)()

local M = {}

M.pending = {}
M.shutdown = function() end

local _id = 0
local get_next_id = function()
  _id = _id + 1
  return _id
end

M.notifications = {}

M.add_notification_handler = function(name, func)
  M.notifications[name] = func
end

-- Process vars, could be encapsulated some other way, but this is fine for now.
local handle, pid, stdin, stdout, stderr = nil, nil, nil, nil, nil
M.start = function(force)
  -- Debugging usefulness
  if force or handle == nil then
    M.shutdown()

    if env.token() == "" then
      vim.notify("[cody] Missing SRC_ACCESS_TOKEN env var", vim.log.levels.WARN)
    end

    if not env.endpoint() or env.endpoint() == "" then
      vim.notify("[cody] Missing SRC_ENDPOINT env var", vim.log.levels.WARN)
    end

    stdin = assert(uv.new_pipe())
    stdout = assert(uv.new_pipe())
    stderr = assert(uv.new_pipe())

    handle, pid = uv.spawn(bin_sg_cody, {
      stdio = { stdin, stdout, stderr },
      env = {
        "PATH=" .. vim.env.PATH,
        "SRC_ACCESS_TOKEN=" .. env.token(),
        "SRC_ENDPOINT=" .. env.endpoint(),
      },
    }, function(code, signal) -- on exit
      vim.notify "[cody] exited!"

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
                log.info("stdout chunk", parsed)

                if not parsed.id then
                  log.info("got a notification", parsed.method)
                  if M.notifications[parsed.method] then
                    M.notifications[parsed.method](parsed)
                  else
                    log.warn("missing notification handler:", parsed.method)
                  end
                else
                  if M.pending[parsed.id] then
                    M.pending[parsed.id](parsed)
                    M.pending[parsed.id] = nil
                  end
                end
              else
                log.info("failed chunk", parsed)
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

            log.info("chunked", i, vim.json.decode(lines[i]))
          end

          buffer = buffer .. lines[#lines]
          log.info("unchunked... for now!", buffer)
        end
      end
    end))

    stderr:read_start(vim.schedule_wrap(function(err, data)
      if err or data then
        log.info("[cody-stderr] ", err, data)
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

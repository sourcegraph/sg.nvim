local function discover_sg_cody()
  ---@type string | nil
  local cmd = "sg-cody"

  if vim.fn.executable(cmd) ~= 1 then
    cmd = nil
    local cmd_paths = {
      "target/release/sg-cody",
      "target/debug/sg-cody",
      "bin/sg-cody",
    }
    for _, path in ipairs(cmd_paths) do
      local res = vim.api.nvim_get_runtime_file(path, false)[1]
      if res then
        cmd = res
        break
      end
    end
  end

  if cmd == nil then
    error "Failed to load sg-cody: You probably did not run `cargo build --bin sg-cody`"
  end

  return cmd
end
local bin_sg_cody = discover_sg_cody()

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

    if not vim.env.SRC_ACCESS_TOKEN or vim.env.SRC_ACCESS_TOKEN == "" then
      vim.notify("[cody] Missing SRC_ACCESS_TOKEN env var", vim.log.levels.WARN)
    end

    if not vim.env.SRC_ENDPOINT or vim.env.SRC_ENDPOINT == "" then
      vim.notify("[cody] Missing SRC_ENDPOINT env var", vim.log.levels.WARN)
    end

    stdin = assert(uv.new_pipe())
    stdout = assert(uv.new_pipe())
    stderr = assert(uv.new_pipe())

    handle, pid = uv.spawn(bin_sg_cody, {
      stdio = { stdin, stdout, stderr },
      env = {
        "PATH=" .. vim.env.PATH,
        "SRC_ACCESS_TOKEN=" .. (vim.env.SRC_ACCESS_TOKEN or ""),
        "SRC_ENDPOINT=" .. (vim.env.SRC_ENDPOINT or ""),
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

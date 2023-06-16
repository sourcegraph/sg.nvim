print "===== Starting ====="

local uv = vim.loop

local start_process = function()
  local stdin = assert(uv.new_pipe())
  local stdout = assert(uv.new_pipe())
  local stderr = assert(uv.new_pipe())

  local handle, pid = uv.spawn("./target/debug/sg-cody", {
    stdio = { stdin, stdout, stderr },
  }, function(code, signal) -- on exit
    print("exit code", code)
    print("exit signal", signal)
  end)

  if not handle then
    error "FAILED TO LOAD HANDLE"
  end

  print("proc opened", handle, pid)

  stdout:read_start(vim.schedule_wrap(function(err, data)
    assert(not err, err)
    print("got something", err, data)

    if data then
      local ok, parsed = pcall(vim.json.decode, data)
      if not ok then
        print("FAILED TO PARSE:", parsed)
      else
        print("stdout chunk", parsed)
      end
    else
      print "stdout end"
    end
  end))

  stderr:read_start(vim.schedule_wrap(function(err, data)
    print("ERROR:", err, data)
  end))

  stdin:write(vim.json.encode { id = 1, payload = { method = "Test" } } .. "\n")

  vim.defer_fn(function()
    uv.shutdown(stdin, function()
      uv.close(handle, function() end)
    end)
  end, 1000)

  return {
    request = function(data, cb) end,
  }
end

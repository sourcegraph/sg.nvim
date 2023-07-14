-- TODO: Can switch to vim.system later
local system = function(cmd, opts)
  local status = {}
  opts = opts or {}

  opts.on_stdout = function(_, data)
    print(table.concat(data, ""))
  end
  opts.on_stderr = function(_, data)
    print(table.concat(data, ""))
  end

  opts.on_exit = function(code)
    if code ~= 0 then
      error("failed to execute: " .. table.concat(cmd, " "))
    end

    status.done = true
    print ""
  end

  vim.fn.jobstart(cmd, opts)
  return status
end

print "====================="
print "installing sg.nvim..."
print "====================="

-- Wait for up to ten minutes...? Idk, maybe that's too long
-- or short haha. I don't know what build times are for other people
local wait_for_status = function(status)
  vim.wait(10 * 60 * 1000, function()
    return status.done
  end, 10)
end

local status_workspace = system { "cargo", "build", "--workspace" }
wait_for_status(status_workspace)

local status_bins = system { "cargo", "build", "--bins" }
wait_for_status(status_bins)

print "success\n"

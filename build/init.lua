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

  opts.on_exit = function()
    status.done = true
    print ""
  end

  vim.fn.jobstart(cmd, opts)
  return status
end

print "====================="
print "installing sg.nvim..."
print "====================="

local status = system { "cargo", "build", "--workspace", "--bins" }

-- Wait for up to ten minutes...? Idk, maybe that's too long
-- or short haha. I don't know what build times are for other people
vim.wait(10 * 60 * 1000, function()
  return status.done
end, 10)

print "success\n"

local sourced_filename = (function()
  return vim.fn.fnamemodify(vim.fs.normalize(debug.getinfo(2, "S").source:sub(2)), ":p")
end)()

-- Add sourcegraph plugin to runtimepath
-- This let's us require "sg.config" and "sg.build"
vim.opt.rtp:prepend(vim.fn.fnamemodify(sourced_filename, ":h:h"))

local ok, config = pcall(require, "sg.config")
if not ok then
  config = {}
end

-- This is the default path of downloading binaries
if config.download_binaries or config.download_binaries == nil then
  return require("sg.build").download()
else
  -- This is the path to build these manually.

  -- TODO: Can switch to vim.system later
  local system = function(cmd, opts)
    local status = {}
    opts = opts or {}

    opts.on_stdout = function(_, data)
      if data then
        print(table.concat(data, ""))
      end
    end

    opts.on_stderr = function(_, data)
      if data then
        print(table.concat(data, ""))
      end
    end

    opts.on_exit = function(_, code)
      if code ~= 0 then
        status.errored = true
        return
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
      return status.done or status.errored
    end, 200)
  end

  local status_bins = system { "cargo", "build", "--bins" }
  wait_for_status(status_bins)

  if status_bins.errored then
    error "failed to build the binaries"
  end

  print "success\n"
end

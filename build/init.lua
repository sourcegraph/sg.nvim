local ok, config = pcall(require, "sg.config")
if not ok then
  config = {}
end

-- This is the default path of downloading binaries
if config.download_binaries or config.download_binaries == nil then
  local void = require("plenary.async").void
  local uv = require("plenary.async").uv
  local async_system = require("sg.utils").async_system

  local os_uname = vim.loop.os_uname()
  local sysname = os_uname.sysname:lower()
  local machine = os_uname.machine

  local basename = (function()
    if sysname == "linux" then
      return "sg-x86_64-unknown-linux-gnu"
    end

    if sysname == "windows_nt" then
      return "sg-x86_64-pc-windows-msvc"
    end

    if sysname == "darwin" then
      if machine == "arm64" then
        return "sg-aarch64-apple-darwin"
      else
        return "sg-x86_64-apple-darwin"
      end
    end

    error "Must have a valid basename"
  end)()

  local fullname = (function()
    if sysname == "windows_nt" then
      return basename .. ".zip"
    end

    return basename .. ".tar.xz"
  end)()

  local link = "https://github.com/sourcegraph/sg.nvim/releases/latest/download/" .. fullname

  void(function()
    local tarfile = "dist/" .. fullname

    -- TODO: Windows
    --    Check that we have curl
    --    Check what to do to zip

    local curl = async_system { "curl", link, "-L", "-o", tarfile }
    if curl.code ~= 0 then
      vim.print("Failed to execute downloading release", curl)
      return
    end
    print "Done downloading"

    local tar = async_system { "tar", "-xvf", tarfile, "-C", "dist/" }
    if tar.code ~= 0 then
      vim.print("Failed to untar release", tar)
      return
    end
    print "Done extracting"

    local rename = function(bin_name)
      return uv.fs_rename("dist/" .. basename .. "/" .. bin_name, "dist/" .. bin_name)
    end

    local lsp_rename = rename "sg-lsp"
    if lsp_rename ~= nil then
      vim.print("Failed to rename sg-lsp", lsp_rename)
    end

    local agent_rename = rename "sg-nvim-agent"
    if agent_rename ~= nil then
      vim.print("Failed to rename sg-nvim-agent", agent_rename)
    end

    print "Done renaming"
  end)()

  return
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

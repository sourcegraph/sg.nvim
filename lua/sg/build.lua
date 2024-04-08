--[[

NOTE!! This file cannot depend on anything besides sg.*
- RTP is not always set up during build time. So don't add anything other items.
- Preferably, this only uses sg.utils

--]]

local sourced_filename = (function()
  return vim.fn.fnamemodify(vim.fs.normalize(debug.getinfo(2, "S").source:sub(2)), ":p")
end)()

local plugin_root = vim.fn.fnamemodify(sourced_filename, ":h:h:h")

local utils = require "sg.utils"
local system = utils.system
local joinpath = utils.joinpath

local os_uname = vim.loop.os_uname()
local sysname = os_uname.sysname:lower()
local machine = os_uname.machine

local move_to_dist = function(basename, bin)
  local destination = joinpath(plugin_root, "dist", bin)

  if not vim.loop.fs_rename(joinpath(plugin_root, "dist", basename, bin), destination) then
    return false
  end

  local new_time = os.time()
  if not vim.loop.fs_utime(destination, new_time, new_time) then
    return false
  end

  return true
end

local download_github_release = function(link, output, callback)
  print(string.format("[sg] Starting download: %s -> %s", link, output))
  system(
    { "curl", link, "-L", "-o", output },
    {},
    vim.schedule_wrap(function(curl)
      if curl.code ~= 0 then
        return callback(true, "[sg] Failed to execute downloading release" .. vim.inspect(curl))
      end

      print(string.format("[sg] Done downloading: %s", link))
      return callback(false)
    end)
  )
end

local download_sg_nvim_binary = function(callback)
  local basename = (function()
    if sysname == "linux" then
      if machine == "aarch64" then
        return "sg-aarch64-unknown-linux-gnu"
      else
        return "sg-x86_64-unknown-linux-gnu"
      end
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
  local tarfile = joinpath(plugin_root, "dist", fullname)

  download_github_release(link, tarfile, function(err, msg)
    if err then
      vim.notify(string.format("%s", msg), vim.log.levels.ERROR, { title = "sg" })
      return
    end

    if sysname == "windows_nt" then
      local zipfile = joinpath(plugin_root, "dist", fullname)

      local unzip = system({
        "powershell",
        "-Command",
        "Expand-Archive",
        "-Path",
        zipfile,
        "-DestinationPath",
        joinpath(plugin_root, "dist"),
      }):wait()
      if unzip.code ~= 0 then
        return callback(true, "Failed to unzip release" .. unzip)
      end
      callback(false)
    else
      local tar = system({ "tar", "-xvf", tarfile, "-C", joinpath(plugin_root, "dist/") }):wait()
      if tar.code ~= 0 then
        return callback(true, "Failed to untar release" .. tar)
      end

      local lsp_rename = move_to_dist(basename, "sg-lsp")
      if not lsp_rename then
        return callback(true, "Failed to rename sg-lsp: " .. vim.inspect(lsp_rename))
      end

      local agent_rename = move_to_dist(basename, "sg-nvim-agent")
      if not agent_rename then
        return callback(true, "Failed to rename sg-nvim-agent" .. vim.inspect(agent_rename))
      end
    end

    callback(false)
  end)
end

local M = {}

-- TODO: Next time I bump the version, we should go and delete old versions of the binary
M._cody_agent_version = "0.0.5"
M._cody_agent_bin =
  joinpath(plugin_root, "dist", string.format("cody-agent-%s", M._cody_agent_version))

local download_cody_agent = function(cb)
  if vim.fn.executable(M._cody_agent_bin) == 1 then
    return cb(false)
  end

  -- Target:
  -- https://github.com/sourcegraph/cody/releases/download/agent-v0.0.5/cody-agent-linux-x64-0.0.5

  -- cody-agent-linux-arm64-0.0.5
  -- cody-agent-linux-x64-0.0.5
  -- cody-agent-macos-arm64-0.0.5
  -- cody-agent-macos-x64-0.0.5
  -- cody-agent-win-x64-0.0.5.exe
  local variant = (function()
    if sysname == "linux" then
      if machine == "aarch64" then
        return "linux-arm64"
      else
        return "linux-x64"
      end
    end

    if sysname == "darwin" then
      if machine == "arm64" then
        return "macos-arm64"
      else
        return "macos-x64"
      end
    end

    if sysname == "windows_nt" then
      return "win-x64"
    end

    error "Must have a valid basename"
  end)()

  local link = string.format(
    "https://github.com/sourcegraph/cody/releases/download/agent-v%s/cody-agent-%s-%s",
    M._cody_agent_version,
    variant,
    M._cody_agent_version
  )

  download_github_release(link, M._cody_agent_bin, function(...)
    -- Set cody agent to be executable and accessible
    vim.fn.setfperm(M._cody_agent_bin, "rwxrwxrwx")

    -- Complete callback
    cb(...)
  end)
end

M.download = function(cb)
  -- TODO: Proper error handling here.
  --    Right now, nvim won't exit with a non-zero exit code
  --    if you run this with nvim -l build/init.lua
  --    because we don't force the error in the main thread.
  --
  --    so we need to vim.wait for them.
  vim.notify("[sg] Starting to download binaries...", vim.log.levels.INFO, { title = "sg" })

  local count, errored = 0, {}
  local download_cb = function(err, msg)
    if err then
      table.insert(errored, msg)
    end

    count = count + 1
    if count == 2 then
      if not vim.tbl_isempty(errored) then
        vim.notify(
          string.format("[sg] Done downloading binaries with errors: %s", vim.inspect(errored)),
          vim.log.levels.ERROR,
          { title = "sg" }
        )
      else
        vim.notify("[sg] Done downloading binaries", vim.log.levels.INFO, { title = "sg" })
      end

      if cb then
        cb()
      end
    end
  end

  download_cody_agent(download_cb)
  download_sg_nvim_binary(download_cb)
end

M.download_sync = function()
  local done = false
  local cb = function()
    done = true
  end

  M.download(cb)

  vim.wait(120 * 1000, function()
    return done
  end)

  vim.notify "[sg] Done downloading binaries"
end

return M

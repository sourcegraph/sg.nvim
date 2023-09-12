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

local M = {}

local tarfile = joinpath(plugin_root, "dist", fullname)
local move_to_dist = function(bin)
  local destination = joinpath(plugin_root, "dist", bin)

  local ok = vim.loop.fs_rename(joinpath(plugin_root, "dist", basename, bin), destination)
  if not ok then
    return ok
  end

  local new_time = os.time()
  return vim.loop.fs_utime(destination, new_time, new_time)
end

M.download = function()
  -- TODO: Proper error handling here.
  --    Right now, nvim won't exit with a non-zero exit code
  --    if you run this with nvim -l build/init.lua
  --    because we don't force the error in the main thread.
  --
  --    so we need to vim.wait for them.
  vim.notify "[sg] Starting to download binaries..."

  -- TODO: Windows
  --    Check that we have curl
  --    Check what to do to zip

  local curl = system({ "curl", link, "-L", "-o", tarfile }):wait()
  if curl.code ~= 0 then
    error("Failed to execute downloading release" .. vim.inspect(curl))
  end
  print "[sg] Done downloading"

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
      error("Failed to unzip release" .. unzip)
    end
    print "[sg] Done extracting"
  else
    local tar = system({ "tar", "-xvf", tarfile, "-C", joinpath(plugin_root, "dist/") }):wait()
    if tar.code ~= 0 then
      error("Failed to untar release" .. tar)
    end
    print "[sg] Done extracting"
  end

  local lsp_rename = move_to_dist "sg-lsp"
  if not lsp_rename then
    error("Failed to rename sg-lsp: " .. vim.inspect(lsp_rename))
    return
  end

  local agent_rename = move_to_dist "sg-nvim-agent"
  if not agent_rename then
    error("Failed to rename sg-nvim-agent" .. vim.inspect(agent_rename))
    return
  end

  vim.notify "[sg] Download complete. Restart nvim"
end

return M

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

  if sysname == "windows" then
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
  if sysname == "windows" then
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

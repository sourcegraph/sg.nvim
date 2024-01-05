-- Just make sure request has started
require("sg.request").start()

local M = {}

local blocking = require("sg.utils").blocking

local report_nvim = function()
  if vim.version.cmp(vim.version(), { 0, 9, 4 }) >= 0 then
    vim.health.ok(string.format("Valid nvim version: %s", tostring(vim.version())))
    return true
  else
    vim.health.error "Invalid nvim version. Upgrade to at least 0.9.4"
    return false
  end
end

local report_lib = function()
  if 1 ~= vim.fn.executable "cargo" then
    vim.health.warn "Unable to find valid cargo executable. Trying to build sg.nvim locally will fail. Instead use `:SourcegraphDownloadBinaries`"
    return true
  else
    local result = require("sg.utils").system({ "cargo", "--version" }, { text = true }):wait()
    if result.code ~= 0 then
      vim.health.warn "cargo failed to run `cargo --version`. Instead use `:SourcegraphDownloadBinaries`"

      for _, msg in ipairs(vim.split(result.stdout, "\n")) do
        vim.health.info(msg)
      end
      for _, msg in ipairs(vim.split(result.stderr, "\n")) do
        vim.health.info(msg)
      end

      return false
    else
      local version = vim.trim(result.stdout or "")
      vim.health.ok(string.format("Found `cargo` (%s) is executable", version))
      vim.health.info "    Use `:SourcegraphDownloadBinaries` to avoid building locally."
    end
  end

  return true
end

local report_nvim_agent = function()
  local ok, nvim_agent = pcall(require("sg.config").get_nvim_agent)
  if ok and nvim_agent then
    vim.health.ok("Found `sg-nvim-agent`: " .. vim.inspect(nvim_agent))
    return true
  else
    vim.health.error("Unable to find `sg-nvim-agent`: " .. vim.inspect(nvim_agent))
    return false
  end
end

local report_env = function()
  local auth = require "sg.auth"

  local ok = true

  local creds = auth.get()
  if not creds then
    vim.health.error "No valid auth strategy detected. See ':help sg' for more info."
    return false
  else
    assert(creds, "must have valid credentials")

    vim.health.ok "  Authentication setup correctly"
    vim.health.ok(string.format("    endpoint set to: %s", creds.endpoint))
  end

  local err, info = blocking(require("sg.rpc").get_info)
  local expected_cargo_version = require "sg.private.cargo_version"
  if err or not info then
    ok = false
  elseif expected_cargo_version ~= info.sg_nvim_version then
    vim.health.error "Mismatched cargo and expected version. Update using :SourcegraphDownloadBinaries or :SourcegraphBuild"
    vim.health.error(string.format("Exptected: %s | Found: %s", expected_cargo_version, info.sg_nvim_version))

    ok = false
  else
    vim.health.ok(
      "Found correct binary versions: "
        .. vim.inspect(expected_cargo_version)
        .. " = "
        .. vim.inspect(info.sg_nvim_version)
    )
  end

  if err or not info then
    vim.health.error("  Sourcegraph Connection info failed: " .. vim.inspect(err))
    ok = false
  else
    vim.health.ok("  Sourcegraph Connection info: " .. vim.inspect(info))
  end

  return ok
end

local report_agent = function()
  local config = require "sg.config"

  local ok, reason = require("sg.utils").valid_node_executable(config.node_executable)
  if not ok then
    vim.health.error("Invalid node executable: " .. vim.inspect(reason))
    return false
  end

  if 1 ~= vim.fn.executable(config.node_executable) then
    vim.health.error(string.format("config.node_executable (%s) not executable", config.node_executable))
    return false
  else
    local result = require("sg.utils").system({ config.node_executable, "--version" }, { text = true }):wait()
    if result.code ~= 0 then
      vim.health.error(
        string.format(
          "config.node_executable (%s) failed to run `%s --version`",
          config.node_executable,
          config.node_executable
        )
      )

      for _, msg in ipairs(vim.split(result.stdout, "\n")) do
        vim.health.info(msg)
      end
      for _, msg in ipairs(vim.split(result.stderr, "\n")) do
        vim.health.info(msg)
      end
    else
      vim.health.ok(
        string.format(
          "Found `%s` (config.node_executable) is executable.\n    Version: '%s'",
          config.node_executable,
          reason
        )
      )
    end
  end

  if not config.cody_agent then
    vim.health.error "Unable to find cody_agent `cody-agent.js` file"
  else
    vim.health.ok(string.format("Found `cody-agent`: %s", config.cody_agent))
  end

  return true
end

local report_cody_account = function()
  if not require("sg.auth").get() then
    vim.health.error "Cannot check Cody Status, not logged in"
    return false
  end
  local err, user_info = blocking(require("sg.rpc").get_user_info)
  if err or not user_info then
    vim.health.error(string.format("Cody Auth Failed: %s", vim.inspect(err)))
    return false
  end

  -- This isn't sensitive, but I think it's just confusing for users
  user_info.id = nil

  vim.health.info "To manage your Cody Account, navigate to: https://sourcegraph.com/cody/manage"
  vim.health.ok(string.format("Cody Account Information: %s", vim.inspect(user_info)))
  return true
end

M.check = function()
  vim.health.start "sg.nvim report"

  local ok = true

  local uname = vim.loop.os_uname()
  vim.health.info(string.format("Machine: %s, sysname: %s", uname.machine, uname.sysname))

  if not report_nvim() then
    vim.health.error "Invalid nvim version. Upgrade to at least 0.9.4 or nightly"
    return
  end

  if not require("sg")._setup_has_been_called then
    vim.health.error "sg.nvim has not been setup. See ':help sg' for more info."
    vim.health.error "Run `require('sg').setup()` somewhere in your configuration"
    return
  end

  ok = report_lib() and ok
  ok = report_nvim_agent() and ok
  ok = report_agent() and ok
  ok = report_env() and ok
  ok = report_cody_account() and ok

  if ok then
    vim.health.ok "sg.nvim is ready to run"
  else
    vim.health.error "sg.nvim has issues that need to be resolved"
  end
end

return M

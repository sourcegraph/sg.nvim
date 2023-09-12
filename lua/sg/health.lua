local void = require("plenary.async").void
local M = {}

local report_nvim = function()
  if vim.version.cmp(vim.version(), { 0, 9, 0 }) >= 0 then
    vim.health.ok "Valid nvim version"
    return true
  else
    vim.health.error "Invalid nvim version. Upgrade to at least 0.9.0"
    return false
  end
end

local report_lib = function()
  if 1 ~= vim.fn.executable "cargo" then
    vim.health.error "Unable to find valid cargo executable. Trying to build sg.nvim will fail. Instead use `:SourcegraphDownloadBinaries`"
    return false
  else
    local result = require("sg.utils").system({ "cargo", "--version" }, { text = true }):wait()
    if result.code ~= 0 then
      vim.health.error "cargo failed to run `cargo --version`. Instead use `:SourcegraphDownloadBinaries`"

      for _, msg in ipairs(vim.split(result.stdout, "\n")) do
        vim.health.info(msg)
      end
      for _, msg in ipairs(vim.split(result.stderr, "\n")) do
        vim.health.info(msg)
      end

      return false
    else
      vim.health.ok "Found `cargo` is executable"
    end
  end

  return true
end

local report_nvim_agent = function()
  local ok, nvim_agent = pcall(require("sg.config").get_nvim_agent)
  if ok then
    vim.health.ok("Found `sg-nvim-agent`: " .. nvim_agent)
    return true
  else
    vim.health.error("Unable to find `sg-nvim-agent`: " .. nvim_agent)
    return false
  end
end

local report_env = function()
  local auth = require "sg.auth"

  local ok = true

  vim.health.info(string.format("Auth strategy order: %s", vim.inspect(require("sg.config").auth_strategy)))

  local all_valid = auth.get_all_valid()
  if vim.tbl_isempty(all_valid) then
    vim.health.error "No valid auth strategy detected. See `:help sg` for more info."
    ok = false
  else
    for idx, valid in ipairs(all_valid) do
      local creds, strategy = unpack(valid)
      assert(creds, "must have valid credentials")

      if idx == 1 then
        vim.health.ok(string.format('  Authentication setup correctly ("%s")', strategy))
        vim.health.ok(string.format("    endpoint set to: %s", creds.endpoint))
      else
        vim.health.ok(string.format('  Backup Authentication also available ("%s")', strategy))
        vim.health.ok(string.format("    endpoint set to: %s", creds.endpoint))
      end
    end
  end

  local err, info
  void(function()
    err, info = require("sg.rpc").get_info()
  end)()

  vim.wait(10000, function()
    return err or info
  end)

  if err or not info then
    vim.health.error("  Sourcegraph Connection info failed: " .. vim.inspect(err))
    ok = false
  else
    vim.health.ok("  Sourcegraph Connection info: " .. vim.inspect(info))
  end

  info = info or {}
  local expected_cargo_version = require "sg.private.cargo_version"
  if expected_cargo_version ~= info.sg_nvim_version then
    vim.health.error "Mismatched cargo and expected version. Update using :SourcegraphDownloadBinaries or :SourcegraphBuild"
    vim.health.error(string.format("Exptected: %s | Found: %s", expected_cargo_version, info.sg_nvim_version))

    ok = false
  else
    vim.health.ok("Found correct binary versions: " .. expected_cargo_version .. " = " .. info.sg_nvim_version)
  end

  return ok
end

local report_agent = function()
  local config = require "sg.config"

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
      vim.health.ok(string.format("Found `%s` (config.node_executable) is executable", config.node_executable))
    end
  end

  if not config.cody_agent then
    vim.health.error "Unable to find cody_agent `cody-agent.js` file"
  else
    vim.health.ok(string.format("Found `cody-agent`: %s", config.cody_agent))
  end

  return true
end

M.check = function()
  vim.health.start "sg.nvim report"

  local ok = true

  ok = report_nvim() and ok
  ok = report_lib() and ok
  ok = report_nvim_agent() and ok
  ok = report_agent() and ok
  ok = report_env() and ok

  if ok then
    vim.health.ok "sg.nvim is ready to run"
  else
    vim.health.error "sg.nvim has issues that need to be resolved"
  end
end

return M

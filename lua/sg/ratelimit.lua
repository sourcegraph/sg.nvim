---@tag sg.upgrade

---@brief [[
--- Cody has two tiers of usage currently available. To see up-to-date
--- information about rate-limiting and usage guidelines, see:
--- - Cody Dashboard: https://sourcegraph.com/cody/manage
--- - Manage your subscription: https://sourcegraph.com/cody/subscription
---
--- - The default version is the Cody Free version.
--- - The Cody Pro version has higher rate limits for both chat and code completions.
---
--- Any questions about accounts or about what might be spurious ratelimiting, please
--- reach out to Sourcegraph at:
--- - https://sourcegraph.com/community
---@brief ]]

local M = {}

-- Current state regarding rate limiting
M.state = {
  -- Whether the user has been rate limited this session
  has_been_ratelimited = false,

  -- Whether the user has been notified of rate limiting yet this session
  has_notified_user = {},
}

M.is_ratelimit_err = function(err)
  local has_been_ratelimited = err and err.code == -32000
  if has_been_ratelimited then
    M.state.has_been_ratelimited = true
  end

  return has_been_ratelimited
end

M.notify_ratelimit = function(kind)
  if M.state.has_notified_user[kind] then
    return
  end

  M.state.has_notified_user[kind] = true
  require("sg.rpc").get_user_info(function(err, data)
    if err or not data or not data.cody_pro_enabled then
      vim.notify "[cody] You've reached the limit for the Cody Free version. See `:help sg.upgrade`"
    else
      vim.notify "[cody] You have a pro account, but seem to be getting rate limited. Please reach out to support on https://sourcegraph.com/community for more information."
    end
  end)
end

return M

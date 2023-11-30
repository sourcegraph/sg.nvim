local M = {}

--- Current state regarding rate limiting
M.state = {
  --- Whether the user has been rate limited this session
  has_been_ratelimited = false,

  --- Whether the user has been notified of rate limiting yet this session
  has_notified_user = false,
}

M.is_ratelimit_err = function(err)
  local has_been_ratelimited = err and err.code == -32000
  if has_been_ratelimited then
    M.state.has_been_ratelimited = true
    M.notify_ratelimit()
  end

  return has_been_ratelimited
end

M.notify_ratelimit = function()
  if M.state.has_notified_user then
    return
  end

  M.state.has_notified_user = true
  vim.notify "[cody] No remaining credits for the day. Run `:checkhealth sg` for more info"
end

return M

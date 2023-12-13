local M = {}

--- Current state regarding rate limiting
M.state = {
  --- Whether the user has been rate limited this session
  has_been_ratelimited = false,

  --- Whether the user has been notified of rate limiting yet this session
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
  vim.notify "[cody] No remaining credits for the day. Run `:checkhealth sg` for more info"
end

return M

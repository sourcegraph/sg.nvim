local async = require "plenary.async"

return {
  async = async.wrap(function(a, b, c)
    return vim.system(a, b, vim.schedule_wrap(c))
  end, 3),
}

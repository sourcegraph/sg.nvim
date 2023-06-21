local async = require "plenary.async"

return {
  async = async.wrap(function(a, b, c)
    local system = vim.system or vim._system
    return system(a, b, vim.schedule_wrap(c))
  end, 3),
}

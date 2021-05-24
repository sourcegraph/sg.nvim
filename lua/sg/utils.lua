
local utils = {}

utils.once = function(f)
  local value, called = nil, false
  return function(...)
    if not called then
      value = f(...)
      called = true
    end

    return value
  end
end

return utils

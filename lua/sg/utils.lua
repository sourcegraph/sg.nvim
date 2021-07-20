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

utils.get_word_around_character = function(line, character)
  local match_pat = "[^%w_]"
  local reversed = string.reverse(line)

  local reversed_starting_index = string.find(reversed, match_pat, #line - character, false)
  local start_non_matching_index
  if not reversed_starting_index then
    start_non_matching_index = 0
  else
    start_non_matching_index = #line - reversed_starting_index + 1
  end

  local end_non_matching_index = string.find(line, match_pat, character, false) or (#line + 1)
  return string.sub(line, start_non_matching_index + 1, end_non_matching_index - 1)
end

return utils

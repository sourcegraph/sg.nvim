local input_token = nil
local input_endpoint = nil

return {
  token = function(interactive)
    local token = vim.env.SRC_ACCESS_TOKEN
    if token and token ~= "" then
      return token
    end

    if interactive and not input_token then
      input_token = vim.fn.input "SRC_ACCESS_TOKEN > "
    end

    return input_token
  end,

  endpoint = function(interactive)
    local endpoint = vim.env.SRC_ENDPOINT
    if endpoint and endpoint ~= "" then
      return endpoint
    end

    if interactive and not input_endpoint then
      input_endpoint = vim.fn.input "SRC_ENDPOINT > "
    end

    return input_endpoint
  end,
}

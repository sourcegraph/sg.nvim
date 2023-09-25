local traverse
traverse = function(t, f)
  for k, v in pairs(t) do
    f(t, k, v)

    if type(v) == "table" then
      traverse(v, f)
    end
  end
end

local logger = require("plenary.log").new {
  plugin = "sg",
  level = "info",
  info_level = 3,
}

-- logger.

local modes = {
  "trace",
  "debug",
  "info",
  "warn",
  "error",
  "datal",
}

local filtered_keys = {
  SRC_ACCESS_TOKEN = true,
  accessToken = true,
}

local modified = {}

for _, level in ipairs(modes) do
  modified[level] = function(...)
    local arguments = { ... }
    for idx, arg in ipairs(arguments) do
      if type(arg) == "table" then
        arg = vim.deepcopy(arg)
        traverse(arg, function(t, k, _)
          if filtered_keys[k] then
            t[k] = "**** revoked ****"
          end
        end)

        arguments[idx] = arg
      end
    end

    logger[level](unpack(arguments))
  end
end

return modified

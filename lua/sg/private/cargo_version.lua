local sourced_filename = (function()
  return vim.fn.fnamemodify(vim.fs.normalize(debug.getinfo(2, "S").source:sub(2)), ":p")
end)()
local plugin_root = vim.fn.fnamemodify(sourced_filename, ":h:h:h:h")

return (function()
  local lines = vim.fn.readfile(require("sg.utils").joinpath(plugin_root, "Cargo.toml"))
  for _, line in ipairs(lines) do
    if vim.startswith(line, "version =") then
      return vim.trim(vim.split(line, "=")[2]:gsub('"', ""))
    end
  end

  error "[sg] unable to find cargo version"
end)()

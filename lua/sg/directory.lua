local M = {}

local load_once = function(f)
  local resolved = nil
  return function(...)
    if resolved == nil then
      resolved = f()
    end

    return resolved(...)
  end
end

local path_tail = function(p)
  return vim.fn.fnamemodify(p, ":t")
end

local file_extension = function(p)
  return vim.fn.fnamemodify(p, ":e")
end

M.transform_path = load_once(function()
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")

  if has_devicons then
    if not devicons.has_loaded() then
      devicons.setup()
    end

    return function(filename, is_directory)
      local basename = path_tail(filename)
      local icon, icon_highlight

      if is_directory then
        -- TODO: This is a hack and only works if you have lir installed...
        --  Perhaps we should just copy theirs and add our own override
        icon, icon_highlight = devicons.get_icon("lir_folder_icon", basename, { default = true })
      else
        icon, icon_highlight = devicons.get_icon(basename, file_extension(basename), { default = false })
      end

      if not icon then
        icon, icon_highlight = devicons.get_icon(basename, nil, { default = true })
      end

      local icon_display = (icon or " ") .. " " .. (filename or "")
      return icon_display, icon_highlight
    end
  else
    return function(filename)
      return filename
    end
  end
end)

return M

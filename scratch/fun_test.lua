local greeting = function(name)
  print(string.format("Hello %s!", name))
end

-- TOOD: This could be a cool pattern to explore doing more fp style stuff
-- local __ = setmetatable({}, {
--   __index = function(_, k)
--     return function(item)
--       return function(data)
--         item(data[k])
--       end
--     end
--   end
-- })
-- __.buf(protocol.did_focus)

local ok, msg = pcall(require, "sg.bufread")
if not ok then
  print("failed to load sg.bufread with msg:", msg)
  return
end

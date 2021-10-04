local lib = R "libsg_nvim"

local commit = lib.get_remote_hash("github.com/neovim/neovim", "HEAD~8")
print("Commit:", commit)
if not commit or string.find(commit, "failed") then
  return
end

local y = lib.get_remote_file_contents("github.com/neovim/neovim", commit, "src/nvim/autocmd.c")

print(">", y[1])
print(">", y[2])
print(">", y[39])

print "Asking remote file..."
local rf = lib.get_remote_file "https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c?L10:5"
print("Remote:", rf.remote)

print "trying contents..."
-- print("contents", rf:read())
print(rf.read)

-- lib.docs(function(get)
--   get("https://google.com", function(body)
--     print("GOOGLE:", string.sub(body, 1, 100))
--   end)

--   get("https://github.com", function(body)
--     print("GITHUB:", string.sub(body, 1, 100))
--   end)
-- end)

-- P(lib.tokio_hello "https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c")

-- local contents = lib.get_remote_contents {
--   remote = "github.com/neovim/neovim",
--   commit = "HEAD",
--   path = "src/nvim/autocmd.c",
-- }

-- if contents then
--   print(string.sub(contents, 1, 100))
-- end

-- -- local contents = lib.get_remote_contents(rf.remote, rf.commit, rf.path)
-- -- print(contents)

-- local reader = rf.read
-- print("Reader:", reader)

-- local contents = rf:read()
-- print("Contents:", string.sub(contents, 1, 100))

local lib = R "libsg_nvim"

local commit = lib.get_remote_hash("github.com/neovim/neovim", "HEAD")
local y = lib.get_remote_file_contents("github.com/neovim/neovim", commit, "README.md")

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

-- local rf = lib.get_remote_file "https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c?L10:5"
-- print("Remote:", rf.remote)

-- -- local contents = lib.get_remote_contents(rf.remote, rf.commit, rf.path)
-- -- print(contents)

-- local reader = rf.read
-- print("Reader:", reader)

-- local contents = rf:read()
-- print("Contents:", string.sub(contents, 1, 100))

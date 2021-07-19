-- R("sourcegraph").run { "Query", "file:go", "m.Migration", cwd = "~/sourcegraph/sourcegraph.git/main" }
-- R("sourcegraph").run { "nlua", cwd = "~/build/neovim/", remote = "https://github.com/neovim/neovim" }

R("sourcegraph").run {
  -- Just search for the string
  "RunDocker",

  -- Search all of sourcegraph's repos
  remote = "https://github.com/sourcegraph/sourcegraph",
}

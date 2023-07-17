
### PR Review Format:

- go to github for PR
- click button, opens PR in neovim
  - could probably use diffview.nvim or octo.nvim
- use sourcegraph code intel on both sides of PR so you can navigate as normal
  - QUESTION: When you're in diff mode, and you move to a new file, does the other
    window follow you to the new file as well?

### Search for something (maybe under your cursor) in your whole organization

- I ask `src` for results of search (can make more complicated)
- I get ther results back & parse them
- I display in telescope all the results
- ????
  - Open web link via xdg-open
  - Open virtual file (so sourcegraph://repo/commit/path/to/file)
    - Doesn't save the file and doesn't have the rest of the files.
    - Could use sourcegraph to jump to definition, references, etc.
  - Save files, can use worktree to do magic things here
- Save files, can use worktree to do magic things here- Save files, can use worktree to do magic things here
- Profit

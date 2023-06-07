# sg.nvim

sg.nvim is a plugin focused on bringing many of the features of sourcegraph.com into Neovim.

**Status**: Alpha (see #Features for currently supported features)

## Bug Reporting

If you encounter a bug, please run `:SourcegraphInfo` and copy the contents of the information into your bug report.
It will greatly help in debugging what is happening (and there will probably be some bugs to start... Sorry!)

## Setup

### Connection

You can connect to an existing Sourcegraph instance using the same environment variables
that are used for `src-cli`. See [this](https://github.com/sourcegraph/src-cli#log-into-your-sourcegraph-instance) for more information.

If you have these environment variables set when opening Neovim, you'll connect to your
instance of Sourcegraph

## Features:

- [x] Read files:
  - [x] Directly from sourcegraph links: `:edit <sourcegraph url>`
    - `sg.nvim` will automatically add protocols for handling `https://sourcegraph.com/*` links.
  - [x] Directly from buffer names: `:edit sg://github.com/tjdevries/sam.py/-/src/sam.py`
  - [x] Use `:SourcegraphLink` to get a link for the location under your cursor
- [x] Reading non-files:
  - [ ] Repository roots
  - [x] Folders
    - [x] Expand Folders
    - [x] Unexpand Folders
    - [x] Open file from folder
- [x] Use builtin LSP client to connect to SG
  - [x] Goto Definition
  - [ ] Goto References
    - [x] <20 references
    - [ ] kind of broken right now for lots of references
- [x] Basic Search
  - [x] literal, regexp and structural search support
  - [x] `type:symbol` support
  - [ ] repo support
- [ ] Advanced Search Features
  - [ ] Autocompletion
  - [ ] Memory of last searches
- More ??

## Installation

```lua
-- Use your favorite package manager to install, for example in lazy.nvim
return {
  {
    "sourcegraph/sg.nvim",
    build = "cargo build --workspace",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
```

You also need to have the appropriate environment variables to log in to your sourcegraph instance, as described in https://github.com/sourcegraph/src-cli#log-into-your-sourcegraph-instance

### Nix(OS)

The project is packaged as a [Nix Flake][nix-flakes]. Consume it as you normally would. In your Nix configuration,
*make sure* that sg-nvim is included *both* as a Neovim plugin *and* as an environment/user package
(because `sg-lsp` needs to be on your PATH).

See [Neovim guide on NixOS wiki](https://nixos.wiki/wiki/Neovim) for more details on configuration
See [gh:willruggiano/neovim.drv](https://github.com/willruggiano/neovim.drv) for a practical configuration.

For Nix contributors and maintainers:

- Little change is needed to the Nix portion with respect to the growing Rust project
- Feel free to `nix flake update` every once in a while to make sure `flake.lock` is up-to-date
- [ ] Minimal `sg.nvim`-integrated neovim package for testing and example
- [ ] Integrate [Hercules CI](https://hercules-ci.com/) for testing & binary cache
- [ ] Integrate `sg.nvim` onto [nixpkgs:vimPlugins](https://github.com/NixOS/nixpkgs/tree/fe2fb24a00ec510d29ccd4e36af72a0c55d81ec0/pkgs/applications/editors/vim/plugins)

### Setup:

```lua
-- Setup the LSP server to attach when you edit an sg:// buffer
require("sg").setup {
  -- Pass your own custom attach function
  --    If you do not pass your own attach function, then the following maps are provide:
  --        - gd -> goto definition
  --        - gr -> goto references
  on_attach = your_custom_lsp_attach_function
}


```vim
" Example mapping for doing searches from within neovim (may change)
nnoremap <space>ss <cmd>lua require('sg.telescope').fuzzy_search_results()<CR>
```

## Demos:

- Latest Demo: [Alpha Release](https://youtu.be/j5sfHG3z3ao)
- Short clip of cross repository jump to definition: [Clip](https://clips.twitch.tv/AmazonianSullenSwordBloodTrail-l8H5WKEd8sNpEdIT)
- Demo v2: [YouTube](https://www.youtube.com/watch?v=RCyBnAx-4Q4)
- Demo v1: [YouTube](https://youtu.be/iCdsD6MiLQs)

[nix-flakes]: https://nixos.wiki/wiki/Flakes

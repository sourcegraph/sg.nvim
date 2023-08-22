# sg.nvim

**Status**: Beta

## Table of Contents

- [Setup](#setup)
- [Installation](#installation)
- [Configuration](#configuration)

sg.nvim is a plugin focused on bringing many of the features of sourcegraph.com into Neovim.

## Setup

To configure logging in:

- Log in on your Sourcegraph instance.
- Click your user menu in the top right, then select Settings > Access tokens.
- Create your access token, and then run `:SourcegraphLogin` in your neovim editor after installation.
- Type in the link to your Sourcegraph instance (for example: `https://sourcegraph.com`)
- And then paste in your access token.

An alternative to this is to use the environment variables specified for [src-cli](https://github.com/sourcegraph/src-cli#log-into-your-sourcegraph-instance).

You can check that you're logged in by then running `:checkhealth sg`

## Installation

### Requirements

Requires:

- nvim 0.9 or nvim nightly
- Node.js >= 18.17.0 (LTS) at runtime for [`cody-agent.js`](github.com/sourcegraph/cody)

(By default, sg.nvim downloads released binaries from Github. If you prefer to build the plugin yourself, you'll need `cargo` to build)


### Install

<details>
<summary><code>lazy.nvim</code></summary>

```lua
-- Use your favorite package manager to install, for example in lazy.nvim
return {
  {
    "sourcegraph/sg.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "VeryLazy",

    -- If you have a recent version of lazy.nvim, you don't need to add this!
    build = "nvim -l build/init.lua",
  },
}
```
</details>

<details>
<summary><code>packer.nvim</code></summary>

```lua
-- Packer.nvim, also make sure to install nvim-lua/plenary.nvim
use { 'sourcegraph/sg.nvim', run = 'nvim -l build/init.lua' }
```
</details>

<details>
<summary><code>vim-plug</code></summary>

```vimrc
" Using vim-plug
Plug 'sourcegraph/sg.nvim', { 'do': 'nvim -l build/init.lua' }
```
</details>

After installation, run `:checkhealth sg`.

(Nix instructions at the end of the readme)

## Configuration:

```lua
-- Sourcegraph configuration. All keys are optional
require("sg").setup {
  -- Pass your own custom attach function
  --    If you do not pass your own attach function, then the following maps are provide:
  --        - gd -> goto definition
  --        - gr -> goto references
  on_attach = your_custom_lsp_attach_function
}
```

```vim
" Example mapping for doing searches from within neovim (may change) using telescope.
" (requires telescope.nvim to be installed)
nnoremap <space>ss <cmd>lua require('sg.extensions.telescope').fuzzy_search_results()<CR>
```

## Demos:

- Latest Demo: [Alpha Release](https://youtu.be/j5sfHG3z3ao)
- Short clip of cross repository jump to definition: [Clip](https://clips.twitch.tv/AmazonianSullenSwordBloodTrail-l8H5WKEd8sNpEdIT)
- Demo v2: [YouTube](https://www.youtube.com/watch?v=RCyBnAx-4Q4)
- Demo v1: [YouTube](https://youtu.be/iCdsD6MiLQs)

## Features:

Cody:

- [x] Chat interface and associated commands
- [ ] Autocompletions, prompted
- [ ] Autocompletions, suggested

Sourcegraph Browsing:

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
- More? Make an issue with something you're missing :)


### Nix(OS)

The project is packaged as a [Nix Flake][nix-flakes]. Consume it as you normally would. In your Nix configuration,
*make sure* that sg-nvim is included *both* as a Neovim plugin *and* as an environment/user package
(because `sg-lsp` needs to be on your PATH).

See [Neovim guide on NixOS wiki](https://nixos.wiki/wiki/Neovim) for more details on configuration
See [gh:willruggiano/neovim.drv](https://github.com/willruggiano/neovim.drv) for a practical configuration.

For Nix contributors and maintainers:

- Feel free to `nix flake update` every once in a while to make sure `flake.lock` is up-to-date
- [ ] Minimal `sg.nvim`-integrated neovim package for testing and example
- [ ] Integrate `sg.nvim` + Cody onto [nixpkgs:vimPlugins](https://github.com/NixOS/nixpkgs/tree/fe2fb24a00ec510d29ccd4e36af72a0c55d81ec0/pkgs/applications/editors/vim/plugins)

You will also need to add the built `.cdylib` onto `package.cpath`. Here is one example
using [gh:willruggiano/neovim.nix](https://github.com/willruggiano/neovim.nix):

```nix
sg = let
  system = "x86_64-linux";
  package = inputs.sg-nvim.packages.${system}.default;
in {
  inherit package;
  init = pkgs.writeTextFile {
    name = "sg.lua";
    text = ''
      return function()
        package.cpath = package.cpath .. ";" .. "${package}/lib/?.so;${package}/lib/?.dylib"
      end
    '';
  };
};
```

[nix-flakes]: https://nixos.wiki/wiki/Flakes
[crate2nix]: https://github.com/kolloch/crate2nix


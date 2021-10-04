# sg.nvim

sg.nvim is a plugin focused on bringing many of the features of sourcegraph.com into Neovim.

## Implemented Features:

- Reading files by pasting sourcegraph.com links into nvim
  - Will currently cache the files locally so that the next time you read them it will be fast.
- Jump-to-definition using builtin LSP + src-cli (documentation pending)
- References using builtin LSP + src-cli (documentation pending)


## Demos:

- Short clip of cross repository jumpt to definition: [Clip](https://clips.twitch.tv/AmazonianSullenSwordBloodTrail-l8H5WKEd8sNpEdIT)

- Demo v2: [YouTube](https://www.youtube.com/watch?v=RCyBnAx-4Q4)
- Demo v1: [YouTube](https://youtu.be/iCdsD6MiLQs)

## Installation

Don't install it yet. I will fix up a few things and then write installation
and setup instructions (including how to connect builtin LSP to this).

### Installation

Ok, so I said don't install it but you are welcome to try it out, it just probably won't work for you yet.

Requirements:
- [src-cli](https://github.com/sourcegraph/src-cli)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

Setup:

```lua
-- Setup the LSP server to attach when you edit an sg:// buffer
require("sg.lsp").setup {
  ... -- whatever you normally pass to your LSP configuration. on_attach, etc.
}
```

`sg.nvim` will automatically add protocols for handling
`https://sourcegraph.com/*` links.

You should be able to paste in a link like:
- https://sourcegraph.com/github.com/sourcegraph/sourcegraph/-/blob/internal/conf/reposource/jvm_packages.go?L50:6

and have that just open up the file. You can try out different patterns and tell me what stuff doesn't work.

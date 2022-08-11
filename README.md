# sg.nvim

sg.nvim is a plugin focused on bringing many of the features of sourcegraph.com into Neovim.

## Demos:

- Short clip of cross repository jumpt to definition: [Clip](https://clips.twitch.tv/AmazonianSullenSwordBloodTrail-l8H5WKEd8sNpEdIT)

- Demo v2: [YouTube](https://www.youtube.com/watch?v=RCyBnAx-4Q4)
- Demo v1: [YouTube](https://youtu.be/iCdsD6MiLQs)

## Installation

Don't do it...

### Installation

Ok fine.


You'll need a Sourcegraph Access token (I think, or you'll get rate limited most likely)

```bash
SRC_ACCESS_TOKEN=...
```

Setup:

```lua
require("sg").setup {
  -- Attach to LSP with your normal keymaps
  on_attach = custom_lsp_attach
}
```

In some terminal, you'll need to run first:

```bash
cargo build --workspace
```

and then run (at some point this will be automatic, but I'm not sure how to do that at this point:

```bash
cargo run --bin daemon
```

Then hopefully when you open up a sourcegraph URL it will work in your neovim :)

# Experimental Features

These are experimental features. There are no promises that they will continue
working or even exist going forward. Use at your own risk ;)

## Process of "un-experimenting"

If you have:

```lua
-- lua/sg/cody/experimental/x.lua
return { ... }
```

and then you want to graduate to something else, do this:

```lua
-- lua/sg/cody/experimental/x.lua
vim.notify("sg.cody.experimental.x has moved to sg.cody.x, you should require from there")
return require "sg.cody.x"
```

And then just replace all the `experimental` requires locally to the updated one

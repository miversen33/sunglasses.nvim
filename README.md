# sunglasses.nvim

Put on your shades so you only see what you care about

<!-- Insert Gallery Screenshots with a handful of themes here -->

## Features

- Able to be used with **any** neovim _or_ vim theme
- Easy to Setup
- Easy to Customize
- No external dependencies
- Works with Sessions
- _Only a minimal amount of shenanigans happening!_

## Requirements

- Currently only supports neovim 0.9 newer

## Installation

### Lazy

```lua
require("lazy").setup({"miversen33/sunglasses.nvim", config = true})
```

#### Super Lazy
If you want, you can lazy load sunglasses, tied to the UIEnter event.
By default though, sunglasses already does most of its "work" after this
event fires so you aren't really gaining much by lazy loading sunglasses.

But I am not here to stop you from getting every last millisecond shaved
off your startup time so here ya go


```lua
require("lazy").setup({"miversen33/sunglasses.nvim", config = true, event = "UIEnter"})

```

## Configuration

Sunglasses has sane defaults (as shown below) and therefore doesn't require configuration to get started. However, if you would like below is the list of defaults and changes that can be applied to them

```lua
-- lua
local sunglasses_defaults = {
    filter_percent = 0.65,
    filter_type = "SHADE",
    log_level = "ERROR",
    refresh_timer = 5,
    excluded_filetypes = {
        "dashboard",
        "lspsagafinder",
        "packer",
        "checkhealth",
        "mason",
        "NvimTree",
        "neo-tree",
        "plugin",
        "lazy",
        "TelescopePrompt",
        "alpha",
        "toggleterm",
        "sagafinder",
        "better_term",
        "fugitiveblame",
        "starter",
        "NeogitPopup",
        "NeogitStatus",
        "DiffviewFiles",
        "DiffviewFileHistory",
        "DressingInput",
        "spectre_panel",
        "zsh",
        "registers",
        "startuptime",
        "OverseerList",
        "Navbuddy",
        "noice",
        "notify",
        "saga_codeaction",
        "sagarename"
    },
    excluded_highlights = {
        "WinSeparator",
        {"lualine_.*", glob = true},
    }
}

-- The above table will is the default configuration.
-- If you do not wish to set any configuration options, you can simply
-- pass nil into your setup
require("sunglasses").setup()
-- Or you can provide your own values. Please configure your
-- options by looking at each option available and setting it
require("sunglasses").setup({
    filter_percent = 0.65,
    filter_type = "SHADE",
    log_level = "ERROR",
    refresh_timer = 5,
    excluded_filetypes = {
        "dashboard",
        "lspsagafinder",
        "packer",
        "checkhealth",
        "mason",
        "NvimTree",
        "neo-tree",
        "plugin",
        "lazy",
        "TelescopePrompt",
        "alpha",
        "toggleterm",
        "sagafinder",
        "better_term",
        "fugitiveblame",
        "starter",
        "NeogitPopup",
        "NeogitStatus",
        "DiffviewFiles",
        "DiffviewFileHistory",
        "DressingInput",
        "spectre_panel",
        "zsh",
        "registers",
        "startuptime",
        "OverseerList",
        "Navbuddy",
        "noice",
        "notify",
        "saga_codeaction",
        "sagarename"
    },
    excluded_highlights = {
        "WinSeparator",
        {"lualine_.*", glob = true},
    }
})
```

### Config.filter_percent
Version Added: 0.1
Default: .65

This is the percentage to modify inactive buffer's highlights. This value must
be between 0 and 1 and is clamped as such. An example of how to use this is
as follows

```lua
-- lua
local sunglasses_options = {
    filter_percent = 0.65
}

require("sunglasses").setup(sunglasses_options)
```

### Config.filter_type
Version Added: 0.1
Default: "SHADE"

This is the kind of filter to apply to inactive buffers. Valid filter_types
are
- "SHADE"
- "TINT"

An example of how to use this is as follows

```lua
-- lua
local sunglasses_options = {
    filter_type = "SHADE"
}

require("sunglasses").setup(sunglasses_options)
```

### Config.log_level
Version Added: 0.1
Default: "ERROR"

This is the level to filter all logs against. This means that logs with a
level under "ERROR" will not be written to the file. If you are looking to
submit a bug report, please set this to a lower level.

Your sunglasses log can be located with the following command
```lua
-- lua
print(vim.fn.stdpath('log') .. '/sunglasses.log')
```

Below are a list of valid log levels (in filter order). Anything lower than the
level in this list will be filtered at that level. As an example, with a level
of "ERROR" (the default), logs of level "WARNING" will be filtered

- "CRITICAL"
- "ERROR"
- "WARNING"
- "INFO"
- "DEBUG"
- "TRACE"
- "TRACE2"
- "TRACE3"

**** Be aware, any of the trace levels will very quickly produce lots of logs

An example of how to set this is as follows
```lua
-- lua
local sunglasses_options = {
    filter_level = "ERROR"
}
require("sunglasses").setup(sunglasses_options)
```

### Config.refresh_timer
Version Added: 0.1
Default: 5

This tells sunglasses how often (in seconds) to refresh its internal
highlights cache. This is how sunglasses is able to deal with highlight groups
that are dynamically created over time.

An example of how to set this is as follows
```lua
-- lua
local sunglasses_options = {
    refresh_timer = 5
}
require("sunglasses").setup(refresh_timer)
```

### Config.excluded_filetypes
Version Added: 0.1
Default:
```lua
-- lua
{
    "dashboard",
    "lspsagafinder",
    "packer",
    "checkhealth",
    "mason",
    "NvimTree",
    "neo-tree",
    "plugin",
    "lazy",
    "TelescopePrompt",
    "alpha",
    "toggleterm",
    "sagafinder",
    "better_term",
    "fugitiveblame",
    "starter",
    "NeogitPopup",
    "NeogitStatus",
    "DiffviewFiles",
    "DiffviewFileHistory",
    "DressingInput",
    "spectre_panel",
    "zsh",
    "registers",
    "startuptime",
    "OverseerList",
    "Navbuddy",
    "noice",
    "notify",
    "saga_codeaction",
    "sagarename"
}
```

This is a list of filetypes to be excluded when shading inactive windows.

**If you are making changes to this table, consider submitting a PR to**
**update it for everyone instead!**

An example of how to set this is as follows

```lua
-- lua
local sunglasses_options = {
    excluded_filetypes = {
        "lazy"
    }
}
require("sunglasses").setup(sunglasses_options)
```

### Config.excluded_highlights
Version Added: 0.1
Default:
```lua
-- lua
{
    "WinSeparator",
    {"lualine_.*", glob = true},
}
```

This is a list of highlights to exclude modifying on inactive windows.

**If you are making changes to this table, consider submitting a PR to**
**update it for everyone instead!**

Entries in this table can be either a string or a table (as shown above).
If its a string, it is treated as the exact name of the highlight to exclude.
If it is in table form (and has the `glob = true` value in the table), then
it is treated as a glob in which all highlights that *match* the glob are
excluded.

You may be wondering why lualine is included here. It seems that vim will
apply the namespace highlight to lualine in the event that all other windows
in the tabpage are already in that namespace. That makes lualine look super
weird, so this fixes that.

An example of how to set this is as follows
```lua
-- lua
local sunglasses_options = {
    excluded_highlights = {
        "WinSeparator"
    }
}
require("sunglasses").setup(sunglasses_options)
```

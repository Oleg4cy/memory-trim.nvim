# memory-trim.nvim

Small Neovim plugin for releasing unused memory after memory-heavy transient operations. It always performs Lua garbage collection and, where available, additionally calls `malloc_trim(0)`. It also includes optional automatic cleanup after Telescope pickers close.

The plugin cannot and should not promise to restore RSS to its exact startup value. Loaded Lua modules, native allocations, allocator fragmentation, Neovim state, and other plugins may legitimately remain resident.

## Features

- Manual memory collection
- Optional native allocator trimming
- Automatic cleanup after Telescope picker close
- Telescope-independent core
- No polling
- No recurring timers
- Lazy-loading friendly
- Graceful fallback when native trimming is unavailable

## Requirements

- Neovim
- Telescope is optional and is required only when Telescope integration is enabled
- Native `malloc_trim` support depends on the platform and libc; it is not required

## Installation

With [Lazy.nvim](https://github.com/folke/lazy.nvim), enable Telescope cleanup with:

```lua
{
  "Oleg4cy/memory-trim.nvim",
  ft = "TelescopePrompt",
  opts = {
    telescope = true,
  },
}
```

This keeps memory-trim.nvim unloaded until a Telescope prompt actually appears.

For the manual API without Telescope integration:

```lua
{
  "Oleg4cy/memory-trim.nvim",
  lazy = true,
}

Lazy.nvim will automatically load the plugin when `require("memory-trim")` is first used.
```

## Usage

Collect memory explicitly:

```lua
require("memory-trim").collect()
```

Lua garbage collection is always attempted. The boolean result is `true` when native `malloc_trim` reports that memory was released. `false` does not mean that Lua garbage collection failed; it means that native trimming was unavailable or reported that no memory was released.

Check native allocator support:

```lua
require("memory-trim").can_trim()
```

This reports whether native allocator trimming is available.

Enable optional Telescope cleanup:

```lua
require("memory-trim").setup({
  telescope = true,
})
```

Telescope cleanup is opt-in.

## Telescope integration

The integration watches buffers with the standard `TelescopePrompt` filetype, reacts when a picker closes, and performs one cleanup deferred by 100 ms so Telescope teardown can finish first. It does not monkey-patch Telescope internals or poll in the background.

This applies to Telescope pickers using the standard `TelescopePrompt` filetype; compatibility with every third-party Telescope extension is not guaranteed.

Telescope's `cache_picker` setting is separate from memory-trim.nvim and is not modified by this plugin.

## Health check

Run:

```vim
:checkhealth memory-trim
```

The health check verifies that the public module and API are available and reports whether native allocator trimming can be used. Telescope is optional and is not required by the check.

## Testing

The standalone tests can be run with:

```sh
nvim --headless -u tests/minimal_init.lua -l tests/allocator_spec.lua
nvim --headless -u tests/minimal_init.lua -l tests/telescope_spec.lua
```

These tests run independently of the user's normal Neovim configuration and do not require Telescope to be installed.

## Performance

There is no polling and no recurring timer. Core work happens only when explicitly requested, while Telescope cleanup runs only after a Telescope prompt closes. With Lazy filetype loading, the plugin need not be loaded at startup. The plugin does not claim zero overhead.

## License

See the separate `LICENSE` file. Licensing will be finalized separately.

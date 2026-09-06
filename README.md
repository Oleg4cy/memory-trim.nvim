# memory-trim.nvim

memory-trim.nvim helps release unused memory after memory-heavy transient operations. It attempts Lua garbage collection and, when available, native `malloc_trim(0)`. It also supports automatic Telescope cleanup. RSS is not guaranteed to return to its exact startup value.

## Features

- Manual memory collection through the Lua API
- Optional native allocator trimming
- Automatic cleanup for the standard TelescopePrompt lifecycle
- Telescope-independent core
- No polling or recurring timers
- Lazy-loading friendly
- Graceful fallback without `malloc_trim`
- No commands or default mappings

## Requirements

- Neovim
- Telescope only for automatic Telescope integration
- Optional native `malloc_trim` support, which depends on the platform and libc

## Installation

With [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Oleg4cy/memory-trim.nvim",
}
```

The repository's Lazy.nvim package metadata provides `TelescopePrompt` lazy-loading and enables the standard Telescope integration.

## Usage

Collect memory explicitly:

```lua
require("memory-trim").collect()
```

`collect()` first attempts Lua garbage collection, then attempts `malloc_trim(0)` when it is available. Both operations are protected, so cleanup failures do not escape into normal user runtime; a Lua-GC failure does not prevent an available native trim from being attempted.

Its single boolean return value describes native trimming only: it is `true` only when `malloc_trim(0)` was available, completed successfully, and returned exactly `1`. It is `false` when native trimming is unavailable, fails, or returns another value. The Lua-GC result is intentionally not represented by this boolean.

Check whether native `malloc_trim` was resolved and is available:

```lua
require("memory-trim").can_trim()
```

`can_trim()` is a capability check and does not run cleanup.

Manual setup can enable the Telescope integration:

```lua
require("memory-trim").setup({
  telescope = true,
})
```

This manual setup is not required for the standard Lazy.nvim installation, whose package metadata supplies this option.

## Telescope integration

The integration attaches to buffers whose filetype is exactly `TelescopePrompt`. Cleanup is triggered when an attached prompt buffer is wiped (`BufWipeout`), then deferred by 100 ms so Telescope teardown can finish first. One prompt buffer schedules one cleanup; an ordinary `BufLeave` or focus change is not the cleanup trigger.

It relies on the normal Neovim `TelescopePrompt` buffer lifecycle. It does not require or configure Telescope, monkey-patch Telescope internals, poll, or use a recurring timer.

Standard Telescope teardown wipes its prompt buffer and therefore triggers this integration. Custom third-party layouts or extensions that keep or reuse the prompt buffer instead may not trigger it.

## Health check

Load the plugin before running the health check when it is not yet on the runtimepath:

```vim
:Lazy load memory-trim.nvim
:checkhealth memory-trim
```

Under the standard package metadata, opening a Telescope picker also loads the plugin.

The healthcheck is passive: it validates the public module and the `collect`, `can_trim`, and `setup` API shape; calls only `can_trim()` to inspect native allocator capability; reports native `malloc_trim` availability; and reports Telescope integration as optional. It does not call `collect()` or `setup()`, run Lua garbage collection, invoke `malloc_trim`, require Telescope, or require the Telescope integration module.

## Testing

Run the standalone suite with:

```sh
nvim --headless -u tests/minimal_init.lua -i NONE -l tests/allocator_spec.lua
nvim --headless -u tests/minimal_init.lua -i NONE -l tests/telescope_spec.lua
nvim --headless -u tests/minimal_init.lua -i NONE -l tests/lazy_spec.lua
nvim --headless -u tests/minimal_init.lua -i NONE -l tests/health_spec.lua
```

- Allocator tests cover public allocator behavior, unavailable or failing FFI/native paths, and Lua-GC failure isolation.
- Telescope tests cover the `BufWipeout` lifecycle, `BufLeave` non-triggering, deferred 100 ms cleanup, repeated setup/idempotency, pending deferred cleanup, and no Telescope dependency.
- Lazy tests cover the root package metadata contract.
- Health tests cover the passive healthcheck contract.

## Performance

There is no polling and no recurring timer. Core work happens only when explicitly requested, while cleanup is scheduled only when an attached `TelescopePrompt` buffer is wiped. Under normal Lazy.nvim behavior, the plugin need not be loaded at startup. The plugin does not claim zero overhead.

## License

MIT. See [LICENSE](LICENSE).

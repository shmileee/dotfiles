# OpenCode and OmO

Chezmoi manages the global OpenCode configuration, the released contextual
notification package declaration, its tmux presentation, and the unified OmO
routing configuration.

Managed targets:

- `~/.config/opencode/opencode.json`
- `~/.config/tmux/tmux.conf`
- `~/.omo/omo.jsonc`

## Contextual notifications

`opencode.json` pins `opencode-contextual-notifier@0.1.0`. OpenCode installs
the npm package with Bun on the next startup, so restart every running OpenCode
process after changing the declaration.

The released package owns the OpenCode event handling and the tmux marker
helper. The managed tmux configuration renders `@opencode_waiting` in the
originating window and clears it when that window is selected or focused. OmO's
`session-notification` hook remains disabled to prevent duplicate macOS
notifications.

The notifier implementation, its tests, and its TypeScript toolchain live in
the package repository and are intentionally not copied into
`~/.config/opencode`.

## Local secrets

OpenCode resolves sensitive values from files that are intentionally not
managed by chezmoi or Git:

- `~/.config/opencode/secrets/home-assistant-mcp-url`
- `~/.config/opencode/secrets/home-assistant-access-token`

Create the directory with mode `0700` and each file with mode `0600` before
starting OpenCode on a new machine. Store only the value in each file, without
quotes.

```sh
install -d -m 700 "$HOME/.config/opencode/secrets"
install -m 600 /dev/null "$HOME/.config/opencode/secrets/home-assistant-mcp-url"
install -m 600 /dev/null "$HOME/.config/opencode/secrets/home-assistant-access-token"
```

OpenCode performs the `{file:...}` substitutions when it loads
`opencode.json`; chezmoi never reads or copies the secret values.

## Corporate overlay

Company-specific MCP configuration belongs in
`~/.config/opencode/opencode.corp.json`. This file is intentionally unmanaged
and should use mode `0600`.

The fish configuration sets `OPENCODE_CONFIG` when the corporate file exists.
OpenCode loads the normal global configuration first and deep-merges the
corporate file afterward, so personal and company-specific MCP entries are both
available without duplicating the personal configuration.

Keep company endpoints, profiles, and credentials in that local overlay. It can
use OpenCode's `{file:...}` syntax for credentials stored in separate local
files.

## Deliberately unmanaged files

- `tui.json` currently contains server-side OpenAgent plugin declarations;
  OpenCode's TUI plugin list is a separate extension surface.
- `opencode-notifier.json` is not referenced by the active contextual notifier.
- `opencode.corp.json` is a machine-local corporate overlay.
- Runtime state, caches, backups, dependency directories, and lockfiles are
  generated locally and remain unmanaged.

---
title: OpenCode and OmO
description: Local secrets, model routing, corporate overlays, and contextual notifications.
---

# OpenCode and OmO

<p class="page-lead">chezmoi manages the shared OpenCode configuration, Oh My OpenAgent routing, Fish integration, and tmux notification plumbing. Secrets and company-specific endpoints stay local.</p>

## What is managed

| Surface | Managed file | Responsibility |
| --- | --- | --- |
| OpenCode | `~/.config/opencode/opencode.json` | Plugins, formatters, language servers, and personal MCP configuration |
| OmO | `~/.omo/omo.jsonc` | Agent categories, model choices, fallbacks, and disabled hooks |
| Fish | `~/.config/fish/conf.d/opencode.fish` | Activate the optional corporate configuration |
| tmux | `~/.config/tmux/tmux.conf` | Install the contextual-notifier companion plugin |

The OpenCode configuration currently declares the Claude authentication,
Oh My OpenAgent, and contextual-notifier plugins. OpenCode installs declared
plugins with Bun when it starts.

## First-run checklist

1. Apply the dotfiles through the [setup guide](what-how-and-why.md).
2. Create the local secret files if you want to use the Home Assistant MCP server.
3. Put only the secret value in each file—no quotes or shell assignment.
4. Start a new Fish shell so an optional corporate overlay is detected.
5. Restart every running OpenCode process after changing plugin declarations.

## Local secrets

The managed OpenCode file references two files that are deliberately absent
from Git:

- `~/.config/opencode/secrets/home-assistant-mcp-url`
- `~/.config/opencode/secrets/home-assistant-access-token`

Create them with restrictive permissions:

```bash
install -d -m 700 "$HOME/.config/opencode/secrets"
install -m 600 /dev/null "$HOME/.config/opencode/secrets/home-assistant-mcp-url"
install -m 600 /dev/null "$HOME/.config/opencode/secrets/home-assistant-access-token"
```

Edit each file and store only its value. OpenCode resolves the `{file:...}`
references when it loads the configuration; chezmoi never reads or copies the
secret contents.

!!! warning "The files start empty"

    The `install` commands create secure placeholders. Populate them before
    enabling or using the Home Assistant MCP integration.

## Corporate overlay

Put company-specific OpenCode configuration in:

```text
~/.config/opencode/opencode.corp.json
```

This file is unmanaged and should use mode `0600`:

```bash
install -m 600 /dev/null "$HOME/.config/opencode/opencode.corp.json"
```

When the file exists, the managed Fish snippet exports `OPENCODE_CONFIG`
pointing to it. Keep company endpoints, profiles, and credentials there rather
than adding them to the personal repository. The overlay can use the same
`{file:...}` syntax for credentials stored in separate local files.

Start a new Fish shell—or source the managed snippet—after creating or removing
the overlay.

## Model routing

`~/.omo/omo.jsonc` is the routing source of truth. It assigns primary and
fallback models to named agents and task categories, and enables model
fallback when the first choice is unavailable.

Model names change more often than the surrounding workflow, so consult the
managed file for the current assignments rather than copying a list from this
page. The `session-notification` hook is disabled there because notifications
are handled by the dedicated contextual-notifier plugin.

## Contextual notifications

OpenCode pins `opencode-contextual-notifier@0.1.2`. Its tmux companion is
declared through TPM in the managed `tmux.conf`.

Together they mark the originating tmux window when an OpenCode session needs
attention and clear that state when the window is selected or focused. The
notifier's implementation and tests live in its own package repository; this
dotfiles repository only declares and configures it.

After changing the notifier declaration:

1. restart OpenCode so Bun can synchronize the package;
2. reload tmux with ++ctrl+a++ then ++ctrl+r++; and
3. run the TPM installation flow if the companion plugin is not present yet.

## Deliberately unmanaged

| Path or category | Why it stays local |
| --- | --- |
| `opencode.corp.json` | Contains company-specific configuration |
| Files under `opencode/secrets/` | Contain credentials or private endpoints |
| `tui.json` | Uses a separate server-side extension surface |
| `opencode-notifier.json` | Is not referenced by the active notifier |
| Caches, backups, lockfiles, and dependency directories | Are generated at runtime |

## Troubleshooting

### An MCP server fails during startup

Confirm that both secret files exist, contain a value, and use mode `0600`:

```bash
stat -f '%Sp %N' "$HOME/.config/opencode/secrets/"*  # macOS
stat -c '%A %n' "$HOME/.config/opencode/secrets/"*  # Linux
```

### The corporate configuration is ignored

Open a new Fish shell and confirm the variable points to the expected file:

```fish
echo $OPENCODE_CONFIG
```

### A notification or tmux marker is stale

Focus the originating tmux window first. If the marker remains, restart
OpenCode and reload tmux configuration with ++ctrl+a++ then ++ctrl+r++.

---
title: OpenCode configuration
description: Local secrets, model routing, corporate overlays, and contextual notifications.
---

# OpenCode + OmO

<p class="page-lead">chezmoi, the dotfile manager, manages the shared OpenCode configuration, Oh My OpenAgent routing, fish integration, and tmux notification plumbing. Secrets and company-specific endpoints stay local.</p>

<details class="concept-primer" data-mobile-toc-anchor markdown>
<summary>
  <span class="concept-primer__summary"><strong>Quick context</strong><small>Plain-language definitions</small></span>
  <svg class="concept-primer__chevron" viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="m4 6 4 4 4-4" /></svg>
</summary>
<dl class="concept-primer__terms">
  <div><dt>OpenCode</dt><dd>An AI coding tool that can use models, plugins, formatters, and external services.</dd></div>
  <div><dt>OmO</dt><dd>Oh My OpenAgent, the layer that assigns agents and task categories to models.</dd></div>
  <div><dt>MCP</dt><dd>Model Context Protocol, a standard for connecting an AI tool to external services.</dd></div>
  <div><dt>Model routing</dt><dd>Rules that choose a primary model and fallbacks for each kind of task.</dd></div>
  <div><dt>Hook</dt><dd>Logic that runs automatically when a specific OpenCode event occurs.</dd></div>
  <div><dt>TPM</dt><dd>The tmux Plugin Manager, used to install and update tmux extensions.</dd></div>
</dl>
</details>

## What is managed

<div class="surface-grid">
  <article>
    <span>OpenCode</span>
    <a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_opencode/opencode.json" aria-label="Open the managed OpenCode configuration on GitHub"><code class="path-token">~/.config/<wbr>opencode/<wbr>opencode.json</code></a>
    <p>Plugins, formatters, language servers, and personal MCP configuration.</p>
  </article>
  <article>
    <span>OmO</span>
    <a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/config/private_dot_omo/omo.jsonc" aria-label="Open the managed OmO configuration on GitHub"><code class="path-token">~/.omo/<wbr>omo.jsonc</code></a>
    <p>Agent categories, model choices, fallbacks, and disabled hooks.</p>
  </article>
  <article>
    <span>fish</span>
    <a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_fish/conf.d/opencode.fish" aria-label="Open the managed fish configuration on GitHub"><code class="path-token">~/.config/<wbr>fish/<wbr>conf.d/<wbr>opencode.fish</code></a>
    <p>Activates the optional corporate configuration.</p>
  </article>
  <article>
    <span>tmux</span>
    <a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf" aria-label="Open the managed tmux configuration on GitHub"><code class="path-token">~/.config/<wbr>tmux/<wbr>tmux.conf</code></a>
    <p>Installs the contextual-notifier companion plugin.</p>
  </article>
</div>

The OpenCode configuration currently declares the `opencode-claude-auth`, Oh
My OpenAgent, and contextual-notifier plugins. OpenCode installs these plugins
with Bun when it starts.

## First-run checklist

1. Apply the dotfiles with the [setup guide](setup.md).
2. Create the local secret files if you want to use the Home Assistant MCP server.
3. Put only the secret value in each file—no quotes or variable names.
4. Start a new fish shell so an optional corporate overlay is detected.
5. Restart all running OpenCode processes after changing plugin declarations.

## Local secrets

The managed OpenCode file references two files that are intentionally not
tracked by Git:

- <code class="path-token">~/.config/<wbr>opencode/<wbr>secrets/<wbr>home-assistant-mcp-url</code>
- <code class="path-token">~/.config/<wbr>opencode/<wbr>secrets/<wbr>home-assistant-access-token</code>

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

When the file exists, the managed fish snippet sets `OPENCODE_CONFIG` to its
path. Keep company endpoints, profiles, and credentials there rather
than adding them to the personal repository. The overlay can use the same
`{file:...}` syntax for credentials stored in separate local files.

Start a new fish shell—or source the managed snippet—after creating or removing
the overlay.

## Model routing

[`~/.omo/omo.jsonc`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_omo/omo.jsonc)
is the routing source of truth. It assigns primary and fallback models to named
agents and task categories, using a fallback when the first choice is
unavailable.

Model names change more often than the surrounding workflow, so consult the
managed file for the current assignments rather than copying a list from this
page. The `session-notification` hook is disabled there because notifications
are handled by the dedicated contextual-notifier plugin.

## Contextual notifications

OpenCode declares the
[`opencode-contextual-notifier`](https://github.com/shmileee/opencode-contextual-notifier)
package in the managed
[`opencode.json`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_opencode/opencode.json).
Its tmux companion is declared through TPM in the managed
[`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf).

Together they mark the originating tmux window when an OpenCode session needs
attention and clear that state when the window is selected or focused. The
notifier package repository contains its implementation and tests; this
dotfiles repository only declares and configures it.

After changing the notifier declaration:

1. Restart OpenCode so Bun can synchronize the package.
2. Reload tmux with ++ctrl+a++ then ++ctrl+r++.
3. Run the TPM installation flow if the companion plugin is not present.

## Deliberately unmanaged

<div class="boundary-list">
  <div><code>opencode.corp.json</code><span>Company-specific configuration</span></div>
  <div><code>opencode/secrets/</code><span>Credentials and private endpoints</span></div>
  <div><code>tui.json</code><span>A separate server-side extension surface</span></div>
  <div><code>opencode-notifier.json</code><span>Not referenced by the active notifier</span></div>
  <div><strong>Runtime files</strong><span>Caches, backups, lockfiles, and dependency directories</span></div>
</div>

## Troubleshooting

### An MCP server fails to start

Confirm that both secret files exist, contain a value, and use mode `0600`:

```bash
stat -f '%Sp %N' "$HOME/.config/opencode/secrets/"*  # macOS
stat -c '%A %n' "$HOME/.config/opencode/secrets/"*  # Linux
```

### The corporate configuration is ignored

Open a new fish shell and confirm that the variable points to the expected file:

```fish
echo $OPENCODE_CONFIG
```

### A notification or tmux marker is stale

Focus the originating tmux window first. If the marker remains, restart
OpenCode and reload tmux configuration with ++ctrl+a++ then ++ctrl+r++.

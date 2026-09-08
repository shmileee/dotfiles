---
title: OpenCode configuration
description: Local secrets, model routing, corporate overlays, contextual notifications, and local voice dictation.
tags:
  - OpenCode
  - AI tooling
  - tmux
  - chezmoi
  - Voice
hide:
  - tags
---

# OpenCode + OmO

<p class="page-lead" data-mobile-toc-anchor>chezmoi, the dotfile manager, manages the shared OpenCode configuration, Oh My OpenAgent routing, fish integration, and tmux notification plumbing. Secrets and company-specific endpoints stay local.</p>

<section class="context-help-source" hidden data-search-exclude>
<button class="context-help-trigger" type="button" aria-label="Open quick context" aria-controls="context-help" aria-haspopup="dialog" title="Quick context" data-context-open data-context-ui><span aria-hidden="true">?</span></button>
<dialog class="context-help" id="context-help" aria-labelledby="context-help-title" data-context-dialog data-context-ui>
<div class="context-help__panel">
<header class="context-help__header">
  <div><p>Quick context</p><h2 id="context-help-title" data-search-exclude>Terms used on this page</h2></div>
  <button type="button" aria-label="Close quick context" data-context-close><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="m4 4 8 8m0-8-8 8" /></svg></button>
</header>
<dl class="context-help__terms">
  <div><dt>OpenCode</dt><dd>An AI coding tool that can use models, plugins, formatters, and external services.</dd></div>
  <div><dt>OmO</dt><dd>Oh My OpenAgent, the layer that assigns agents and task categories to models.</dd></div>
  <div><dt>MCP</dt><dd>Model Context Protocol, a standard for connecting an AI tool to external services.</dd></div>
  <div><dt>Model routing</dt><dd>Rules that choose a primary model and fallbacks for each kind of task.</dd></div>
  <div><dt>Hook</dt><dd>Logic that runs automatically when a specific OpenCode event occurs.</dd></div>
  <div><dt>TPM</dt><dd>The tmux Plugin Manager, used to install and update tmux extensions.</dd></div>
  <div><dt>LaunchAgent</dt><dd>A macOS service definition that launchd starts and keeps running for the logged-in user.</dd></div>
</dl>
</div>
</dialog>
</section>

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
  <article>
    <span>OpenCode TUI</span>
    <a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_opencode/tui.json" aria-label="Open the managed OpenCode TUI configuration on GitHub"><code class="path-token">~/.config/<wbr>opencode/<wbr>tui.json</code></a>
    <p>Theme, keybinds, and the client-side plugins including voice dictation.</p>
  </article>
</div>

`opencode.json` declares the `opencode-claude-auth`, Oh My OpenAgent, and
contextual-notifier plugins. The TUI loads its own `tui.json`, which declares
Oh My OpenAgent again alongside the voice plugin. OpenCode installs every
declared plugin with Bun when it starts.

## First-run checklist

1.  Apply the dotfiles with the [setup guide](setup.md).
2.  Create the local secret files if you want to use the Home Assistant MCP
    server.
3.  Put only the secret value in each file—no quotes or variable names.
4.  Start a new fish shell so an optional corporate overlay is detected.
5.  Restart all running OpenCode processes after changing plugin declarations.

## Local secrets

The managed OpenCode file references two files that are intentionally not
tracked by Git:

*   <code class="path-token">~/.config/<wbr>opencode/<wbr>secrets/<wbr>home-assistant-mcp-url</code>
*   <code class="path-token">~/.config/<wbr>opencode/<wbr>secrets/<wbr>home-assistant-access-token</code>

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

When the file exists, the managed `opencode` fish wrapper function sets
`OPENCODE_CONFIG` to its path for that invocation—but only when the current
directory is under `~/ghq/workgit/`. Personal repositories always use the
default configuration, even on a machine that has the corporate overlay. Keep
company endpoints, profiles, and credentials in the overlay rather than adding
them to the personal repository. The overlay can use the same `{file:...}`
syntax for credentials stored in separate local files.

The routing is decided per invocation from the working directory, so no shell
restart is needed after creating or removing the overlay.

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

1.  Restart OpenCode so Bun can synchronize the package.
2.  Reload tmux with ++ctrl+a++ then ++ctrl+r++.
3.  Run the TPM installation flow if the companion plugin is not present.

## Voice dictation

++ctrl+r++ records a prompt, transcribes it, and inserts the cleaned text into
the prompt box. Both models run on this machine, so no audio leaves it.

The plugin is declared in the managed
[`tui.json`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_opencode/tui.json),
which also frees ++ctrl+r++ by disabling the factory `session_rename`
binding—rename a session with `/rename` instead. The plugin talks to two local
services:

<div class="surface-grid">
  <article>
    <span>Transcription</span>
    <code class="path-token">127.0.0.1:8081</code>
    <p>whisper.cpp behind a managed LaunchAgent, biased with a project vocabulary.</p>
  </article>
  <article>
    <span>Normalization</span>
    <code class="path-token">127.0.0.1:11434</code>
    <p>ollama serving <code>voice-normalize</code>, which repunctuates the raw transcript.</p>
  </article>
</div>

The models are roughly 3 GB, so they are installed on demand rather than during
provisioning:

```bash
mise run voice:setup
```

The task is idempotent. It verifies the whisper checksum, brings ollama up,
rebuilds the derived model from its Modelfile, restarts the transcription
service, and probes both endpoints before reporting success.

| Managed file | Role |
| --- | --- |
| `bin/whisper-voice-server` | Starts `whisper-server` with the vocabulary as its initial prompt. |
| `bin/ollama-serve` | Starts `ollama serve` and caps its log. |
| `.config/ollama/voice-normalize.Modelfile` | Pins the base checkpoint and bakes in deterministic sampling. |
| `.config/opencode/voice-vocabulary.txt` | Tool names fed to whisper so it stops mangling them. |
| `.config/opencode/voice-stt-prompt.md` | System prompt that cleans up the raw transcript. |

Both services are LaunchAgents declared in this repository rather than
`brew services` entries, so the bind address, tuning flags, and log paths are
reviewable here instead of being whatever the Homebrew formula ships. Nothing
in this repository starts `brew services`, so a machine that had the Homebrew
`ollama` service running needs it stopped once by hand—it binds the same port.

| Managed service | Role |
| --- | --- |
| `Library/LaunchAgents/com.shmileee.whisper-voice-server.plist` | Keeps whisper.cpp running and owns `~/Library/Logs/whisper-voice-server.log`. |
| `Library/LaunchAgents/com.shmileee.ollama.plist` | Keeps `ollama serve` bound to loopback and owns `~/Library/Logs/ollama.log`. |

Neither log is rotated by launchd, so each wrapper truncates its own in place
once it grows past a limit.

### Editing the vocabulary or the prompt

The two text files reload differently:

*   `voice-vocabulary.txt` is read by `whisper-server` when it starts, so it
    needs a service restart: `chezmoi apply` then `mise run voice:setup`.
*   `voice-stt-prompt.md` is read by the plugin when OpenCode starts, so it
    needs `chezmoi apply` and an OpenCode restart. `voice:setup` does nothing
    for it.

!!! warning "whisper truncates a long vocabulary from the front"

    The initial prompt is capped at 224 tokens and whisper keeps the last 223,
    so a vocabulary that grows past the cap loses its opening entries in
    silence. Add terms that are actually mangled rather than every installed
    binary.

## Deliberately unmanaged

<div class="boundary-list">
  <div><code>opencode.corp.json</code><span>Company-specific configuration</span></div>
  <div><code>opencode/secrets/</code><span>Credentials and private endpoints</span></div>
  <div><strong>Runtime files</strong><span>Caches, backups, lockfiles, and dependency directories</span></div>
  <div><strong>Voice models</strong><span>The whisper weights and ollama blobs installed by <code>voice:setup</code></span></div>
</div>

## Troubleshooting

### An MCP server fails to start

Confirm that both secret files exist, contain a value, and use mode `0600`:

```bash
stat -f '%Sp %N' "$HOME/.config/opencode/secrets/"*  # macOS
stat -c '%A %n' "$HOME/.config/opencode/secrets/"*  # Linux
```

### The corporate configuration is ignored

`OPENCODE_CONFIG` is set per invocation by the `opencode` wrapper function,
only inside `~/ghq/workgit/`—a bare `echo $OPENCODE_CONFIG` in a shell is
expected to print nothing. Confirm the overlay file exists and that the
wrapper resolves it from a corporate checkout:

```fish
cd ~/ghq/workgit/Trackunit/<repo>
test -f ~/.config/opencode/opencode.corp.json; and echo overlay present
functions opencode | grep -q workgit; and echo wrapper active
```

### A notification or tmux marker is stale

Focus the originating tmux window first. If the marker remains, restart
OpenCode and reload tmux configuration with ++ctrl+a++ then ++ctrl+r++.

### Voice recording does nothing

Check that the transcription service is loaded, running, and answering:

```bash
launchctl print "gui/$(id -u)/com.shmileee.whisper-voice-server" | grep 'state ='
curl -s http://127.0.0.1:8081/health
```

A job that is loaded but not running means the wrapper diagnosed something and
stopped deliberately—it reports success so launchd does not retry a condition
only a person can clear. The reason is at the end of its log:

```bash
tail -n 20 ~/Library/Logs/whisper-voice-server.log
```

It reports two: a missing model, cleared by `mise run voice:setup`, and another
process already holding the port.

```bash
lsof -nP -iTCP:8081 -sTCP:LISTEN
```

### Dictation is transcribed but the inserted text is wrong

That is the normalization step rather than whisper. Confirm its agent is up and
the derived model answers:

```bash
launchctl print "gui/$(id -u)/com.shmileee.ollama" | grep 'state ='
ollama list | grep voice-normalize
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"voice-normalize","max_tokens":16,"messages":[{"role":"user","content":"ping"}]}'
```

`mise run voice:setup` runs the same probe and rebuilds the model from its
Modelfile.

If the agent will not stay up, check that a Homebrew service is not competing
for the port. Only a machine provisioned before this agent existed can have
one, and stopping it is a one-time fix:

```bash
brew services list | grep ollama
```

```bash
brew services stop ollama
```

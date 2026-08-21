# Zellij terminal workflow

## Installation and managed files

The `zellij` Ansible role installs Zellij `0.45.0` into
`~/.local/lib/zellij/0.45.0` and links `~/.local/bin/zellij` to that version.
It also installs zjstatus `0.24.0` at
`~/.local/share/zellij/plugins/zjstatus.wasm`. The shared Homebrew package list
installs `kubectx`, which provides both `kubectx` and `kubens`. The role selects
explicit arm64 or x86_64 Zellij release assets for macOS and Debian, then
verifies the SHA-256 checksums for both downloads. Install or update the full
terminal stack with:

```bash
ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
  ansible-playbook -e "ansible_user=$(whoami)" \
  scripts/common/ansible/main.yaml --tags common,zellij
```

Chezmoi manages these runtime targets:

| Target | Purpose |
|---|---|
| `~/.config/zellij/config.kdl` | Session, clipboard, mouse, and key bindings |
| `~/.config/zellij/layouts/main.kdl` | Pinned zjstatus layout |
| `~/.config/alacritty/alacritty.toml` | Startup and macOS shortcut routing |
| `~/bin/zellij-action` | Quiet session-wide Alacritty actions |
| `~/bin/zellij-new-tab` | Create a `fish` tab and return to normal mode |

## Startup and lifecycle

Alacritty starts Fish and runs `zellij attach --create main`. This attaches to
the persistent `main` session or creates it when it is absent. If Alacritty is
started from inside Zellij, it opens a plain Fish shell instead of nesting
another session.

The supported model is one Alacritty window and one client attached to `main`.
Closing or detaching the client leaves the server alive for later reattachment.
Session serialization is disabled, so a server or machine restart does not
resurrect panes or relaunch commands from the dead session.

Long-lived sessions keep environment values from their creation time. If
`SSH_AUTH_SOCK` or another agent variable becomes stale, detach, kill or recreate
the Zellij session when it is safe to stop its processes, then attach again.

## Alacritty shortcuts

`Cmd+1` through `Cmd+9`, `Ctrl+Tab`, `Ctrl+Shift+Tab`, `Cmd+W`, and `Cmd+X`
invoke `~/bin/zellij-action`. These commands target `main` and are session-wide.
They quietly do nothing when `main` does not exist. If multiple clients are ever
attached, an external action can affect whichever pane or tab the session treats
as focused, so the one-client assumption must be preserved.

`Cmd+T` is different. Alacritty sends the client-local `Ctrl+a c` terminal key
sequence, which creates a `fish` tab for that client and returns to normal mode.

| Shortcut | Behavior |
|---|---|
| `Cmd+1` through `Cmd+9` | Select numbered tab 1 through 9 |
| `Ctrl+Tab` | Select the next tab |
| `Ctrl+Shift+Tab` | Select the previous tab |
| `Cmd+T` | Create a tab named `fish` |
| `Cmd+W` or `Cmd+X` | Close the focused pane using Zellij's native cascade |
| `Cmd+=` or `Cmd++` | Increase Alacritty font size |
| `Cmd+-` | Decrease Alacritty font size |
| `Cmd+0` | Reset Alacritty font size |

## Prefix bindings and tab names

`Ctrl+a` enters a one-shot tmux-style prefix mode. Actions return to normal mode
unless they enter scroll or rename mode.

| Binding | Behavior |
|---|---|
| `Ctrl+a h/j/k/l` | Focus the pane left, down, up, or right |
| `Ctrl+a Tab` | Toggle to the most recently used tab |
| `Ctrl+a {` / `Ctrl+a }` | Select the previous or next tab |
| `Ctrl+a r` | Rename the current tab |
| `Ctrl+a c` | Create a tab named `fish` |
| `Ctrl+a 1` through `Ctrl+a 9` | Select numbered tab 1 through 9 |
| `Ctrl+a d` | Detach this Zellij client |
| `Ctrl+a Ctrl+c` | Cancel prefix mode |
| `Ctrl+a [` | Enter scroll mode |
| `Ctrl+a \|` | Split into left and right panes |
| `Ctrl+a -` or `Ctrl+a _` | Split into top and bottom panes |
| `Ctrl+a x` | Close the focused pane |
| `Ctrl+a +` | Toggle focused-pane zoom |

Zellij's default `Ctrl+p` mode binding is disabled. Tab numbers in zjstatus
start at 1. New tabs are named `fish` and remain in normal mode. Rename the
current tab explicitly with `Ctrl+a r`. New tabs and panes inherit the current
working directory when Zellij can determine it from the focused pane.

## Scrolling, selection, and clipboard

Zellij owns a 50,000-line scrollback buffer. Mouse mode lets ordinary shell
panes scroll through history while full-screen applications such as Neovim keep
their own mouse handling.

In scroll mode, use `h`, `j`, `k`, `l`, page keys, `Ctrl+b`, `Ctrl+f`, `d`, and
`u` for vi-style movement. On Zellij 0.45.0, `Space` selects the OSC 133 shell
command and output at the scroll cursor; `Enter` copies the selection and returns
to normal mode. Zellij does not expose tmux's arbitrary keyboard visual-selection
action, so command-output selection is the supported keyboard path. Mouse
selection remains available for arbitrary text.

Copy-on-select is enabled. macOS sends copied text through `pbcopy`; Debian and
SSH sessions use Zellij's default OSC52 clipboard path. Normal terminal paste,
including multiline bracketed paste, continues to go directly to Fish or
Neovim.

## Status bar

The bottom layout loads the locally installed zjstatus `0.24.0` WASM. There is
no fallback plugin, so a missing or incompatible local artifact stays visible
in the status pane.

The status area shows the Zellij mode and `main` session, numbered tab names and
the active tab, Kubernetes context and namespace, and the local Warsaw timestamp.
It follows zjstatus's simple example by reading the current context with
`kubectx -c` and namespace with `kubens -c` every two seconds, separated as
`context :: namespace`.

## Dormant tmux fallback

The migration branch keeps the existing tmux package, configuration, TPM, and
plugins. Launch it manually only when Zellij is unavailable:

```bash
fish -lc 'exec tmux -u new-session -As main ";" set-option -g detach-on-destroy off'
```

There is intentionally no alternate Alacritty profile, environment switch, or
fallback shortcut.

## Accepted differences from tmux

The Zellij workflow does not reproduce cross-session linked windows, attach-time
environment refresh, the 20-item tmux paste-buffer ring, exact pane-index swaps,
generic tmux prompts, TPM compatibility, the OpenCode waiting notifier,
automatic session resurrection, pane renaming, or a dedicated close-tab key.

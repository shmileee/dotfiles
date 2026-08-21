# Zellij terminal workflow

## Installation and managed files

The `zellij` Ansible role installs Zellij `0.45.0` into
`~/.local/lib/zellij/0.45.0` and links `~/.local/bin/zellij` to that version.
The role selects explicit arm64 or x86_64 release assets for macOS and Debian,
then verifies their SHA-256 checksums before unpacking them. Run only this role
with:

```bash
ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
  ansible-playbook -e "ansible_user=$(whoami)" \
  scripts/common/ansible/main.yaml --tags zellij
```

Chezmoi manages these runtime targets:

| Target | Purpose |
|---|---|
| `~/.config/zellij/config.kdl` | Session, clipboard, mouse, and key bindings |
| `~/.config/zellij/layouts/main.kdl` | Pinned zjstatus layout |
| `~/.config/alacritty/alacritty.toml` | Startup and macOS shortcut routing |
| `~/bin/zellij-action` | Quiet session-wide Alacritty actions |
| `~/bin/zellij-kube-status` | Local Kubernetes context and namespace status |
| `~/bin/zellij-new-tab` | Create a tab and enter interactive rename mode |

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
sequence, which creates a tab for that client and immediately enters tab rename
mode.

| Shortcut | Behavior |
|---|---|
| `Cmd+1` through `Cmd+9` | Select numbered tab 1 through 9 |
| `Ctrl+Tab` | Select the next tab |
| `Ctrl+Shift+Tab` | Select the previous tab |
| `Cmd+T` | Create a tab and enter tab rename mode |
| `Cmd+W` or `Cmd+X` | Close the focused pane using Zellij's native cascade |
| `Cmd+=` or `Cmd++` | Increase Alacritty font size |
| `Cmd+-` | Decrease Alacritty font size |
| `Cmd+0` | Reset Alacritty font size |

## Prefix bindings and tab names

`Ctrl+a` enters a one-shot prefix mode. Actions return to normal mode
unless they enter scroll or rename mode.

| Binding | Behavior |
|---|---|
| `Ctrl+a h/j/k/l` | Focus the pane left, down, up, or right |
| `Ctrl+a Tab` | Toggle to the most recently used tab |
| `Ctrl+a {` / `Ctrl+a }` | Select the previous or next tab |
| `Ctrl+a r` | Rename the current tab |
| `Ctrl+a c` | Create a tab and immediately rename it |
| `Ctrl+a 1` through `Ctrl+a 9` | Select numbered tab 1 through 9 |
| `Ctrl+a d` | Detach this Zellij client |
| `Ctrl+a [` | Enter scroll mode |
| `Ctrl+a \|` | Split into left and right panes |
| `Ctrl+a -` | Split into top and bottom panes |
| `Ctrl+a x` | Close the focused pane |
| `Ctrl+a +` | Toggle focused-pane zoom |

Tab numbers in zjstatus start at 1. Cancelling rename mode can leave a newly
created tab with its default name. New tabs and panes inherit the current working
directory when Zellij can determine it from the focused pane.

## Scrolling, selection, and clipboard

Zellij owns a 50,000-line scrollback buffer. Mouse mode lets ordinary shell
panes scroll through history while full-screen applications such as Neovim keep
their own mouse handling.

In scroll mode, use `h`, `j`, `k`, `l`, page keys, `Ctrl+b`, `Ctrl+f`, `d`, and
`u` for vi-style movement. On Zellij 0.45.0, `Space` selects the OSC 133 shell
command and output at the scroll cursor; `Enter` copies the selection and returns
to normal mode. Zellij does not expose an arbitrary keyboard visual-selection
action, so command-output selection is the supported keyboard path. Mouse
selection remains available for arbitrary text.

Copy-on-select is enabled. macOS sends copied text through `pbcopy`; Debian and
SSH sessions use Zellij's default OSC52 clipboard path. Normal terminal paste,
including multiline bracketed paste, continues to go directly to Fish or
Neovim.

## Status bar

The bottom layout loads zjstatus `0.24.0` directly from its exact versioned
release URL. There is no fallback plugin, so a download or compatibility failure
stays visible in the status pane.

The status area shows the Zellij mode and `main` session, numbered tab names and
the active tab, Kubernetes context and namespace, and the local Warsaw timestamp
as `YYYY-MM-DD HH:mm:ss`. The Kubernetes helper reads only local kubeconfig data.
Missing `kubectl`, a missing context, or a missing namespace produces no error
output.

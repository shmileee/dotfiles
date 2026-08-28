---
title: Shortcuts
description: Keyboard shortcuts configured for macOS, Alacritty, tmux, and Neovim.
---

# Keyboard shortcuts

<p class="page-lead">Start with the task you want to perform. Alacritty sends many macOS-style shortcuts directly to tmux; tmux commands use <kbd>Ctrl</kbd> + <kbd>A</kbd> as their prefix.</p>

<nav class="shortcut-jump" aria-label="Shortcut groups">
  <a href="#macos-system-shortcuts"><span>01</span>macOS</a>
  <a href="#alacritty-and-tmux"><span>02</span>Direct</a>
  <a href="#tmux-prefix-commands"><span>03</span>tmux prefix</a>
  <a href="#neovim-additions"><span>04</span>Neovim</a>
</nav>

<div class="shortcut-reference" markdown>

## macOS system shortcuts

These mappings are applied by the `system_defaults` Ansible role.

| Shortcut | Action |
| --- | --- |
| ++cmd+g++ | Show Spotlight search |
| ++cmd+space++ | Select the next input source |

The default “select previous input source” shortcut is disabled to prevent it
from competing with the configured next-source binding.

## Alacritty and tmux

These shortcuts work from Alacritty without entering the tmux prefix first.

### Windows and sessions

| Shortcut | Action |
| --- | --- |
| ++cmd+n++ | Open a new Alacritty window |
| ++cmd+t++ | Create a tmux window in the current directory |
| ++cmd+shift+r++ | Rename the tmux session |
| ++cmd+w++ | Kill the current tmux window |
| ++cmd+x++ | Kill the current tmux pane |

### Navigation and search

| Shortcut | Action |
| --- | --- |
| ++ctrl+tab++ | Select the next tmux window |
| ++ctrl+shift+tab++ | Select the previous tmux window |
| ++cmd+1++ … ++cmd+9++ | Select tmux window 1–9 |
| ++cmd+f++ | Enter copy mode and search forward |
| ++cmd+0++ | Reset the Alacritty font size |

## tmux prefix commands

Press ++ctrl+a++, release it, then press the command key.

### Create and arrange

| Command | Action |
| --- | --- |
| ++ctrl+a++ then `c` | Create a window in the current directory |
| ++ctrl+a++ then `r` | Rename the current window |
| ++ctrl+a++ then `R` | Rename the current session |
| ++ctrl+a++ then `\|` | Split the pane horizontally |
| ++ctrl+a++ then `_` | Split the pane vertically |
| ++ctrl+a++ then `+` | Toggle pane zoom |

### Move around

| Command | Action |
| --- | --- |
| ++ctrl+a++ then `h` / `j` / `k` / `l` | Move to the pane on the left / down / up / right |
| ++ctrl+a++ then `[` / `]` | Select the previous / next pane |
| ++ctrl+a++ then `{` / `}` | Select the previous / next window |
| ++ctrl+a++ then ++tab++ | Return to the most recently used window |

### Close and detach

| Command | Action |
| --- | --- |
| ++ctrl+a++ then `x` | Kill the current pane |
| ++ctrl+a++ then `X` | Kill the current window |
| ++ctrl+a++ then ++ctrl+x++ | Confirm and kill every other window |
| ++ctrl+a++ then `Q` | Confirm and kill the session |
| ++ctrl+a++ then `d` | Detach this client |
| ++ctrl+a++ then `D` | Detach other clients when present |

### Configuration and copy mode

| Command | Action |
| --- | --- |
| ++ctrl+a++ then ++ctrl+e++ | Edit `tmux.conf`, then reload it |
| ++ctrl+a++ then ++ctrl+r++ | Reload `tmux.conf` |
| ++ctrl+s++ | Enter copy mode without the prefix |
| ++ctrl+a++ then `p` | Paste the latest tmux buffer |
| ++ctrl+a++ then ++ctrl+p++ | Choose a tmux buffer |

Copy mode uses vi keys and supports the mouse wheel, Page Up/Down, and
Option-based line or half-page scrolling.

## Neovim additions

LazyVim provides most editor mappings. This repository adds only a small layer:

| Mode | Shortcut | Action |
| --- | --- | --- |
| Normal | `o` | Create a blank line below without staying in Insert mode |
| Normal | `O` | Create a blank line above without staying in Insert mode |
| Normal | `<leader><leader>` | Clear search highlighting |
| Visual | `>` / `<` | Indent while keeping the selection active |

</div>

## Source of truth

- macOS shortcuts: [`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
- Alacritty shortcuts: [`alacritty.toml.tmpl`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_alacritty/alacritty.toml.tmpl)
- tmux shortcuts: [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)
- Neovim additions: [`keymaps.lua`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/nvim/lua/config/keymaps.lua)

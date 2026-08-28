---
title: Shortcuts
description: Keyboard shortcuts configured for macOS, Alacritty, tmux, and Neovim.
---

# Keyboard shortcuts

<p class="page-lead">Choose the layer where the shortcut runs. Alacritty sends many macOS-style shortcuts directly to tmux; tmux commands use <kbd>Ctrl</kbd> + <kbd>A</kbd> as their prefix.</p>

<form class="shortcut-filter" role="search" data-shortcut-filter>
  <label for="shortcut-query">Find a shortcut</label>
  <div class="shortcut-filter__search">
    <input id="shortcut-query" type="search" inputmode="search" autocomplete="off" placeholder="Search keys or actions" data-shortcut-query>
    <button type="button" data-shortcut-clear hidden>Clear</button>
  </div>
  <div class="shortcut-filter__scopes" role="group" aria-label="Filter shortcuts by layer">
    <button type="button" aria-pressed="true" data-shortcut-scope="all">All</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="macos">macOS</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="alacritty">Alacritty</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="tmux">tmux</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="neovim">Neovim</button>
  </div>
  <p class="shortcut-filter__status" aria-live="polite" data-shortcut-status></p>
</form>

<p class="shortcut-filter-empty" data-shortcut-empty hidden>No shortcuts match this search.</p>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="macos" markdown>

## macOS system shortcuts

These mappings are applied by the
[`system_defaults`](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/system_defaults)
Ansible role.

| Shortcut | Action |
| --- | --- |
| ++cmd+g++ | Open Spotlight |
| ++cmd+space++ | Select the next input source |

The default shortcut for selecting the previous input source is disabled so it
does not conflict with the configured next-source binding.

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="alacritty" markdown>

## Alacritty and tmux

These shortcuts work from Alacritty without first entering the tmux prefix.

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

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="tmux" markdown>

## tmux prefix commands

Press ++ctrl+a++, release it, and then press the command key.

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
| ++ctrl+a++ then `h` / `j` / `k` / `l` | Move one pane left, down, up, or right |
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
| ++ctrl+a++ then ++ctrl+e++ | Edit [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf), then reload it |
| ++ctrl+a++ then ++ctrl+r++ | Reload [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf) |
| ++ctrl+s++ | Enter copy mode without the prefix |
| ++ctrl+a++ then `p` | Paste the latest tmux buffer |
| ++ctrl+a++ then ++ctrl+p++ | Choose a tmux buffer |

Copy mode uses vi keys and supports the mouse wheel, Page Up and Page Down, and
Option-based scrolling by line or half page.

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="neovim" markdown>

## Neovim additions

LazyVim provides most editor mappings. This repository adds only a small set:

| Mode | Shortcut | Action |
| --- | --- | --- |
| Normal | `o` | Create a blank line below without staying in Insert mode |
| Normal | `O` | Create a blank line above without staying in Insert mode |
| Normal | `<leader><leader>` | Clear search highlights |
| Visual | `>` / `<` | Indent while keeping the selection active |

</section>

## Source of truth

- macOS shortcuts: [`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
- Alacritty shortcuts: [`alacritty.toml.tmpl`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_alacritty/alacritty.toml.tmpl)
- tmux shortcuts: [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)
- Neovim additions: [`keymaps.lua`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/nvim/lua/config/keymaps.lua)

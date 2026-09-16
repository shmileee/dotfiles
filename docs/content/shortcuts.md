---
title: "Keyboard shortcuts"
description: Keyboard shortcuts configured for macOS, Alacritty, fish, tmux, Neovim, and OpenCode.
order: 2
editUrl: https://github.com/shmileee/dotfiles/edit/master/docs/content/shortcuts.md
---

<p>Choose the layer where the shortcut runs. Alacritty, the terminal application, sends many macOS-style shortcuts directly to tmux; fish adds command-line bindings; tmux commands use <kbd>Ctrl</kbd> + <kbd>A</kbd> as their prefix.</p>

<div class="shortcut-filter" role="search" data-shortcut-filter>
  <label for="shortcut-query">Find a shortcut</label>
  <div class="shortcut-filter__search">
    <input id="shortcut-query" type="search" inputmode="search" autocomplete="off" placeholder="Search keys or actions" data-shortcut-query>
    <button type="button" data-shortcut-clear hidden>Clear</button>
  </div>
  <div class="shortcut-filter__scopes" role="group" aria-label="Filter shortcuts by layer">
    <button type="button" aria-pressed="true" data-shortcut-scope="all">All</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="macos">macOS</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="alacritty">Alacritty</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="fish">fish</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="tmux">tmux</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="neovim">Neovim</button>
    <button type="button" aria-pressed="false" data-shortcut-scope="opencode">OpenCode</button>
  </div>
  <p class="shortcut-filter__status" aria-live="polite" data-shortcut-status></p>
</div>

<section class="context-help-source" hidden data-search-exclude data-pagefind-ignore>
<button class="context-help-trigger" type="button" aria-label="Open quick context" aria-controls="context-help" aria-haspopup="dialog" title="Quick context" data-context-open data-context-ui><span aria-hidden="true">?</span></button>
<dialog class="context-help" id="context-help" aria-labelledby="context-help-title" data-context-dialog data-context-ui>
<div class="context-help__panel">
<header class="context-help__header">
  <div><p>Quick context</p><h2 id="context-help-title" data-search-exclude>Terms used on this page</h2></div>
  <button type="button" aria-label="Close quick context" data-context-close><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="m4 4 8 8m0-8-8 8" /></svg></button>
</header>
<dl class="context-help__terms">
  <div><dt>tmux prefix</dt><dd>A key sequence pressed before most tmux commands; here it is Ctrl + A.</dd></div>
  <div><dt>Pane</dt><dd>One terminal area inside a tmux window.</dd></div>
  <div><dt>Window</dt><dd>A tmux workspace that can contain one or more panes.</dd></div>
  <div><dt>Session</dt><dd>A persistent collection of tmux windows that can be detached and reopened.</dd></div>
  <div><dt>Leader</dt><dd>A prefix key used by Neovim mappings; LazyVim normally uses the Space key.</dd></div>
  <div><dt>Normal and Visual mode</dt><dd>Neovim modes for running commands and selecting text.</dd></div>
</dl>
</div>
</dialog>
</section>

<p class="shortcut-filter-empty" data-shortcut-empty hidden>No shortcuts match this search.</p>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="macos">

## macOS system shortcuts

These mappings are applied by the
[`system_defaults`](https://github.com/shmileee/dotfiles/tree/master/bootstrap/ansible/roles/system_defaults)
Ansible role.

| Shortcut | Action |
| --- | --- |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>G</kbd></span> | Open Spotlight |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>Space</kbd></span> | Select the next input source |

The default shortcut for selecting the previous input source is disabled so it
does not conflict with the configured next-source binding.

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="alacritty">

## Alacritty and tmux

These shortcuts work from Alacritty without first entering the tmux prefix.

### Windows and sessions

| Shortcut | Action |
| --- | --- |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>N</kbd></span> | Open a new Alacritty window |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>T</kbd></span> | Create a tmux window in the current directory |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>Shift</kbd><span>+</span><kbd>R</kbd></span> | Rename the tmux session |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>W</kbd></span> | Kill the current tmux window |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>X</kbd></span> | Kill the current tmux pane |

### Navigation and search

| Shortcut | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>Tab</kbd></span> | Select the next tmux window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>Shift</kbd><span>+</span><kbd>Tab</kbd></span> | Select the previous tmux window |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>1</kbd></span> … <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>9</kbd></span> | Select tmux window 1–9 |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>F</kbd></span> | Enter copy mode and search forward |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>0</kbd></span> | Reset the Alacritty font size |

### Links and text

| Shortcut | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>Shift</kbd><span>+</span><kbd>O</kbd></span> | Open a URL or path under the pointer: URLs go to the system opener, files open in a new tmux Neovim window |
| <span class="keys"><kbd>Cmd</kbd><span>+</span><kbd>Shift</kbd><span>+</span><kbd>P</kbd></span> | Copy a visible file path, including its line number when one is present |
| <span class="keys"><kbd>Shift</kbd><span>+</span><kbd>Enter</kbd></span> | Send a Shift-modified Enter that a TUI can tell apart from plain Enter |

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="fish">

## fish shell

These bindings act on the current fish command line.

| Shortcut | Action |
| --- | --- |
| <span class="keys"><kbd>Alt</kbd><span>+</span><kbd>S</kbd></span> | Prepend `sudo` unless the command line already starts with it |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>G</kbd></span> | Open the project chooser powered by fzf |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>T</kbd></span> | Open the fzf directory picker |
| <span class="keys"><kbd>Alt</kbd><span>+</span><kbd>Left</kbd></span> / <span class="keys"><kbd>Alt</kbd><span>+</span><kbd>Right</kbd></span> | Move the cursor one word backward or forward |

Alacritty sets `option_as_alt = "OnlyLeft"`, so the
<span class="keys"><kbd>Alt</kbd></span> bindings above use the left Option key.
fzf runs with `--tmux`, so its pickers open in a tmux popup whenever one is
available. The fzf.fish plugin installs further pickers on its own default keys.

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="tmux">

## tmux prefix commands

Press <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span>,
release it, and then press the command key. Press
<span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> twice to
send a literal
<span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> through to
the program in the pane.

<div class="shortcut-prefix-summary" aria-label="Prefix: Control plus A, then release" data-search-exclude>
  <span class="shortcut-prefix-summary__label">Prefix</span>
  <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span>
  <span class="shortcut-prefix-summary__release">then release</span>
</div>

### Create and arrange

| Command | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `c` | Create a window in the current directory |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `r` | Rename the current window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `R` | Rename the current session |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <code>&#124;</code> | Split the pane horizontally |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `_` | Split the pane vertically |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `+` | Toggle pane zoom |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `m` | Move the current window to a prompted index |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `L` | Link a window from another session |

### Move around

| Command | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `h` / `j` / `k` / `l` | Move one pane left, down, up, or right |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `[` / `]` | Select the previous / next pane |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `{` / `}` | Select the previous / next window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Tab</kbd></span> | Return to the most recently used window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <code>&#92;</code> | Swap the current pane with pane 1, or select pane 1 |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>O</kbd></span> | Rotate the panes downward |

### Agentic tasks

| Command | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>G</kbd></span> | Start or reopen an agent task: pick a repository, name the task, get a git worktree with an OpenCode window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `S` | Create or attach a context session by name, then open the task launcher |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>D</kbd></span> | Open the workmux agent dashboard |

### Close and detach

| Command | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `x` | Kill the current pane |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `X` | Kill the current window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>X</kbd></span> | Confirm and kill every other window |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `Q` | Confirm and kill the session |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `d` | Detach this client |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `D` | Detach other clients when present |

### Configuration and copy mode

| Command | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>E</kbd></span> | Edit [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf), then reload it |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>R</kbd></span> | Reload [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf) |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>S</kbd></span> | Enter copy mode without the prefix |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> `p` | Paste the latest tmux buffer |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>A</kbd></span> <span class="shortcut-then">then</span> <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>P</kbd></span> | Choose a tmux buffer |

Copy mode uses vi keys and supports the mouse wheel, Page Up and Page Down, and
Option-based scrolling by line or half page.

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="neovim">

## Neovim additions

LazyVim provides most editor mappings. This repository overrides or adds the
following. The tag after a key is the mode it works in:
<span class="shortcut-mode">n</span> normal, <span class="shortcut-mode">v</span> visual,
<span class="shortcut-mode">o</span> operator-pending (after `d`, `c` or `y`) and
<span class="shortcut-mode">i</span> insert.

| Shortcut | Action |
| --- | --- |
| `o` <span class="shortcut-mode">n</span> | Create a blank line below without staying in Insert mode |
| `O` <span class="shortcut-mode">n</span> | Create a blank line above without staying in Insert mode |
| `<leader><leader>` <span class="shortcut-mode">n</span> | Clear search highlights |
| `ys` / `ds` / `cs` <span class="shortcut-mode">n</span> | Add, delete, or replace a surrounding pair |
| `<leader>/` <span class="shortcut-mode">n v</span> | Comment the current line or the selection |
| `<S-h>` / `<S-l>` <span class="shortcut-mode">n v</span> | Move the line or selection left or right |
| `<S-j>` / `<S-k>` <span class="shortcut-mode">n v</span> | Move the line or selection down or up |
| `gz` <span class="shortcut-mode">n v</span> | Title-case the line or the selection |
| `w` / `b` <span class="shortcut-mode">n o v</span> | Step by subword, so `camelCase` and `snake_case` split into parts |
| `>` / `<` <span class="shortcut-mode">v</span> | Indent or outdent while keeping the selection active |
| `<C-j>` / `<C-k>` <span class="shortcut-mode">i</span> | Select the next or previous completion item |

Three LazyVim defaults are removed rather than remapped: `<C-s>` for save in
every mode, and the fzf-lua pickers on `<leader><space>` and `<leader>/`. The
second of those keys is reused for commenting above.

</section>

<section class="shortcut-reference shortcut-filter-section" data-shortcut-section="opencode">

## OpenCode

These act inside the OpenCode TUI, so the tmux prefix is not involved.

| Shortcut | Action |
| --- | --- |
| <span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>R</kbd></span> | Record a voice prompt, transcribe it, and insert the cleaned text |

<span class="keys"><kbd>Ctrl</kbd><span>+</span><kbd>R</kbd></span> is
OpenCode's factory binding for renaming a session. The managed `tui.json`
disables that binding so the voice plugin can own the key; rename a session with
the `/rename` command instead.

</section>

## Source of truth

*   macOS shortcuts:
    [`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/bootstrap/ansible/config.yaml)
*   Alacritty shortcuts:
    [`alacritty.toml.tmpl`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_alacritty/alacritty.toml.tmpl)
*   fish shortcuts:
    [`binds.fish`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_fish/conf.d/binds.fish)
*   tmux shortcuts:
    [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)
*   Neovim additions:
    [`keymaps.lua`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/nvim/lua/config/keymaps.lua)
    and
    [`custom.lua`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/nvim/lua/plugins/custom.lua)
*   OpenCode keybinds and voice plugin:
    [`tui.json`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_opencode/tui.json)

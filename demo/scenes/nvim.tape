# LazyVim: dashboard, fzf-lua picker, treesitter highlighting, and the opencode
# theme this palette is shared with. Sourced by demo.tape.

# prefix } -> next-window (the 'editor' window)
Ctrl+A
Type "}"
Sleep 1200ms

# -i NONE keeps the recording out of the real shada file, so nothing in the
# jumplist or oldfiles survives the render.
Type "nvim -i NONE"
Enter
# lazy.nvim's startup varies with what it decides to load, so wait for the
# dashboard's own "loaded N/M plugins in ..." line instead of a fixed sleep.
Wait+Screen /plugins in/
Sleep 1200ms

# <leader> is Space. Pausing after it lets which-key render before the rest of
# the sequence arrives.
Type " "
Sleep 1200ms
Type "ff"
Sleep 1500ms

Type "tokyonight.lua"
Sleep 1500ms
Enter
Sleep 3s

Type "20j"
Sleep 1200ms

# The opencode theme: same six hex values as tmux, lazygit and k9s.
Type " "
Sleep 1000ms
Type "ff"
Sleep 1200ms
Type "tokyonight-transparent"
Sleep 1500ms
Enter
Sleep 3s

Type "10j"
Sleep 1500ms

Escape
Type ":qa!"
Enter
Sleep 1500ms

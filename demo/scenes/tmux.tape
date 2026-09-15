# tmux: status bar, splits, pane dimming, and the themed shell tools.
# Sourced by demo.tape. Prefix is C-a.

Sleep 1s

# Layout first. Filling the panes afterwards means each one draws its prompt at
# its final width; running a command first and splitting after leaves the
# pre-resize prompt on screen beside the reflowed one.
Ctrl+A
Type "|"
Sleep 800ms
Ctrl+A
Type "_"
Sleep 800ms

Type "git log --graph --oneline --decorate --all -8"
Enter
Sleep 2500ms

# prefix [ -> select-pane -t :.-, which also shows the inactive-pane dimming
Ctrl+A
Type "["
Sleep 600ms
# -P disables paging: this pane is ~17 rows, so without it bat hands off to
# less and leaves the pager prompt sitting in the frame.
Type "bat -n -P -r1:15 nvim/lua/plugins/tokyonight.lua"
Enter
Sleep 3s

Ctrl+A
Type "["
Sleep 600ms
# This pane's prompt was drawn before the splits narrowed it; ctrl-l repaints.
Ctrl+L
Sleep 400ms
Type "eza -T -L2 --icons=always"
Enter
Sleep 3s

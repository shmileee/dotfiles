# lazygit: TokyoNight panels, delta diffs, and the branch/commit views.
# Runs against the synthetic repository from sandbox.sh, which is why the
# branch is feature/DOT-42-tokyonight-palette and the history is identical on
# every render. Sourced by demo.tape.

# prefix } -> next-window (the 'git' window)
Ctrl+A
Type "}"
Sleep 1200ms

Type "lazygit"
Enter
Wait+Screen /Local branches/
Sleep 1200ms

# 2 -> Files. The sandbox leaves one staged and one unstaged change, so the
# diff pane has delta output immediately.
Type "2"
Sleep 2s
Down
Sleep 2500ms

# 4 -> Commits, with the diff of whichever commit is selected.
Type "4"
Sleep 2s
Down 2
Sleep 2500ms

# 3 -> Branches.
Type "3"
Sleep 2500ms

Type "q"
Sleep 1500ms

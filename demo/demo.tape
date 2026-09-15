# Hero recording for the README.
#
# Run through demo/render.sh, never directly: the scenes below assume the
# sandbox from demo/sandbox.sh exists and that $DEMO_* and $KUBECONFIG point
# into it. render.sh exports those, which is also why no absolute path appears
# in this file -- the tape stays portable, and VHS' lexer rejects absolute
# paths in Output/Source anyway.

Output dotfiles.gif

Require tmux
Require fish
Require nvim
Require lazygit
Require k9s
Require eza
Require bat

Set Shell "bash"

# The terminal font, at a size that still reads after GitHub scales the GIF
# down to the README column width.
Set FontFamily "FiraCode Nerd Font"
Set FontSize 15
Set LineHeight 1.1

# 1280x800 at this font is ~123x36 cells, which is enough for k9s' wide tables
# without making the GIF heavier than a README should carry.
Set Width 1280
Set Height 800
Set Padding 16

# Lifts the terminal off the README page instead of bleeding into it.
Set Margin 16
Set MarginFill "#1b1d2b"
Set BorderRadius 10

# 20fps is plenty for a terminal and keeps the frame count down.
Set Framerate 20
Set TypingSpeed 40ms

# The scenes wait on rendered text rather than sleeping through TUI startup.
# 40s covers a cold k9s against a freshly created cluster; a real hang still
# fails the render instead of recording a blank pane.
Set WaitTimeout 40s

# TokyoNight moon, identical to the alacritty palette in this repository, so
# anything the applications do not colour themselves still matches.
Set Theme { "name": "TokyoNight Moon", "background": "#222436", "foreground": "#c8d3f5", "selection": "#2d3f76", "cursor": "#c8d3f5", "cursorAccent": "#222436", "black": "#1b1d2b", "red": "#ff757f", "green": "#c3e88d", "yellow": "#ffc777", "blue": "#82aaff", "magenta": "#c099ff", "cyan": "#86e1fc", "white": "#828bb8", "brightBlack": "#444a73", "brightRed": "#ff8d94", "brightGreen": "#c7fb6d", "brightYellow": "#ffd8ab", "brightBlue": "#9ab8ff", "brightMagenta": "#caabff", "brightCyan": "#b2ebff", "brightWhite": "#c8d3f5" }

# --- setup, not recorded ------------------------------------------------------

Hide

# Let the outer shell settle; typing into a prompt that is still initialising
# drops the first character.
Sleep 1500ms

# A dedicated socket and the filtered config from sandbox.sh. Both are passed
# explicitly on every tmux call in this tape, so the live server is never a
# possible target.
Type "tmux -S $DEMO_TMUX_SOCKET -f $DEMO_TMUX_CONF -u new-session -s dotfiles -n shell -c $DEMO_REPO"
Enter
Sleep 4s

# Windows are created with explicit names so the scenes can switch between
# them, and so the config's after-new-window rename prompt has nothing to ask
# about. Inside a pane, bare `tmux` already resolves to this server via $TMUX.
Type "tmux new-window -d -n editor -c $DEMO_REPO && tmux new-window -d -n git -c $DEMO_REPO && tmux new-window -d -n cluster -c $DEMO_REPO && clear"
Enter
Sleep 2s

Show

# --- scenes -------------------------------------------------------------------

Source scenes/tmux.tape
Source scenes/nvim.tape
Source scenes/lazygit.tape
Source scenes/k9s.tape

# next-window wraps, so window 4 -> 1 returns to the split layout the recording
# opened on. The GIF loops, and this keeps the last frame close to the first
# instead of cutting from an empty shell back to the start.
Ctrl+A
Type "}"
Sleep 2500ms

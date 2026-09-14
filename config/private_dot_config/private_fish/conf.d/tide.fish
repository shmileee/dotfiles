# Tide keeps its wizard output in fish universal variables, which chezmoi does
# not manage, so the answers are declared here as `tide configure --auto`
# flags (the tide wiki's recommended way). The guard below re-applies them when
# the flags or the tide version change, not on drift from a manual wizard run.

# Globals shadow tide's universal variables, its documented override mechanism,
# and must be set before the interactive guard below: tide renders the prompt
# in a non-interactive background worker that sources conf.d.
# fish_key_bindings: the worker only forwards fish_bind_mode, so without this
# _tide_item_character falls back to the vi-mode ❮ icon.
# An empty tide_git_icon LIST also drops the icon's trailing space, which
# _tide_item_git concatenates unquoted.
set -g fish_key_bindings fish_default_key_bindings
set -g tide_left_prompt_items pwd git newline character
set -g tide_right_prompt_items status cmd_duration context jobs direnv \
    python go kubectl terraform aws
set -g tide_git_icon

# Tide's own width guard, tide_prompt_min_cols, is read only by the one-line
# prompt, so the two-line prompt overflows $COLUMNS unchecked and fish
# left-truncates the whole line to '…', pwd and branch included. Shadowing
# _tide_right_items (tide's pruned copy of tide_right_prompt_items) with an
# empty global drops the right side instead. The worker re-sources conf.d on
# every render with the live $COLUMNS, so resizes apply at once.
if set -q COLUMNS[1]; and test $COLUMNS -lt 60
    set -g _tide_right_items
end

status is-interactive; or exit
type -q tide; or exit

set -l _tide_flags \
    --style=Rainbow \
    --prompt_colors='True color' \
    --show_time='24-hour format' \
    --rainbow_prompt_separators=Angled \
    --powerline_prompt_heads=Sharp \
    --powerline_prompt_tails=Flat \
    --powerline_prompt_style='Two lines, character' \
    --prompt_connection=Disconnected \
    --powerline_right_prompt_frame=No \
    --prompt_connection_andor_frame_color=Lightest \
    --prompt_spacing=Compact \
    --icons='Many icons' \
    --transient=Yes

set -l _tide_desired (string join ' | ' -- (tide --version) $_tide_flags)

if test "$_tide_dotfiles_config" != "$_tide_desired"
    if tide configure --auto $_tide_flags >/dev/null
        set -U _tide_dotfiles_config $_tide_desired
    else
        echo 'tide configure --auto failed; will retry next shell' >&2
    end
end

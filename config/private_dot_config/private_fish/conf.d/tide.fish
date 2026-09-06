# Reproducible Tide prompt configuration.
#
# Tide stores wizard output in fish universal variables (fish_variables),
# which chezmoi does not manage. The wizard answers are declared below as
# `tide configure --auto` flags — the officially recommended way to sync tide
# config in dotfiles (tide wiki: "Syncing your tide config in your dotfiles").
# They re-apply when the flags or the tide version change (snapshot in the
# _tide_dotfiles_config universal variable). The guard detects recipe edits
# and tide upgrades, NOT runtime drift: a manual `tide configure` run
# persists until the next recipe change, so don't do that — edit this file.

# Globals shadow tide's universal variables — the documented override
# mechanism (tide wiki Configuration: "set --global in your config file").
# Deliberately set BEFORE the interactive guard: tide renders the prompt in a
# non-interactive background worker that sources conf.d, and these must be
# visible there. Unconditional globals also make them immune to wizard resets.
# - fish_key_bindings: the worker only forwards fish_bind_mode; without this,
#   _tide_item_character falls back to the vi-mode ❮ icon instead of ❯
# - left items: no `os` item (mac icon)
# - right items: pruned from the wizard default. `time` dropped — with the
#   transient prompt the timestamp only shows on the current prompt, so it
#   lost its "when did I run this" value in scrollback. Language/tool items
#   for stacks not in use (and gcloud/node) dropped — dead weight per repaint.
# - empty-LIST tide_git_icon drops the branch icon and its trailing space
#   (_tide_item_git concatenates `$tide_git_icon' '` unquoted)
set -g fish_key_bindings fish_default_key_bindings
set -g tide_left_prompt_items pwd git newline character
set -g tide_right_prompt_items status cmd_duration context jobs direnv \
    python go kubectl terraform aws
set -g tide_git_icon

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

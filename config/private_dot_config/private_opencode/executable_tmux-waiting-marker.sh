#!/usr/bin/env bash
#
# OpenCode notifier hook. Invoked as: tmux-waiting-marker.sh {event}
# OpenCode can drop $TMUX_PANE, so the originating pane falls back to matching
# this process's ancestry against tmux pane shell PIDs.
# Rendering + auto-clear-on-focus live in ~/.config/tmux/tmux.conf (it reads
# #{@opencode_waiting} and unsets it on after-select-window/client-focus-in/
# session-window-changed). This script only SETS the option on attention
# events and reports window metadata on request; it never restarts tmux.

set -u

MARKER="●"
OPTION="@opencode_waiting"
EVENT="${1:-}"

[ -n "${TMUX:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

resolve_pane_from_ancestry() {
	local process_id="$$"
	local pane_rows pane_id pane_process_id parent_id
	pane_rows="$(tmux list-panes -a -F '#{pane_id} #{pane_pid}' 2>/dev/null)" || return 1

	while [ "$process_id" -gt 1 ] 2>/dev/null; do
		while read -r pane_id pane_process_id; do
			[ "$process_id" = "$pane_process_id" ] && {
				printf '%s\n' "$pane_id"
				return 0
			}
		done <<<"$pane_rows"
		parent_id="$(ps -o ppid= -p "$process_id" 2>/dev/null)" || return 1
		process_id="${parent_id//[[:space:]]/}"
		[ -n "$process_id" ] || return 1
	done
	return 1
}

PANE="${TMUX_PANE:-}"
if [ -z "$PANE" ]; then
	PANE="$(resolve_pane_from_ancestry)" || exit 0
fi

set_marker() {
	tmux set-option -w -q -t "$PANE" "$OPTION" "$MARKER" 2>/dev/null || true
}

clear_marker() {
	tmux set-option -w -q -u -t "$PANE" "$OPTION" 2>/dev/null || true
}

case "$EVENT" in
permission | question | plan_exit | complete | error)
	set_marker
	;;
user_message | session_started)
	clear_marker
	;;
window_label)
	tmux display-message -p -t "$PANE" '#{window_index}: #{window_name}' 2>/dev/null || true
	;;
*)
	;;
esac

exit 0

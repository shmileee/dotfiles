# OPENCODE_CONFIG routing lives in the opencode wrapper function
# (functions/opencode.fish): corp config applies only under ~/ghq/workgit/.
# Erase values inherited from the environment (older shells exported it
# globally; the tmux global environment may still carry it) so the wrapper's
# per-directory decision is authoritative.
set -e OPENCODE_CONFIG

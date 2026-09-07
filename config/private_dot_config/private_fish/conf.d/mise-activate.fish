status is-interactive; or return

# Never cache `mise activate` output. It bakes in an absolute PATH snapshot
# plus resolved tool install paths, and _source_cached_init only invalidates on
# the mise binary's mtime, so a cached copy replays a stale PATH indefinitely
# and can clobber a newer one. direnv and zoxide emit no such state and stay
# cached.
command -q mise; or return

command mise activate fish | source

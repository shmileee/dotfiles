function opencode --wraps opencode --description "opencode with path-scoped config"
    # Corp config applies only under ~/ghq/workgit (Trackunit); everything
    # else uses the default personal config. Erase any inherited value first
    # (stale tmux global environment, old shells) so routing is deterministic.
    set -e OPENCODE_CONFIG
    set -l corp $HOME/.config/opencode/opencode.corp.json
    if test -f $corp; and string match -q "$HOME/ghq/workgit/*" (pwd -P)
        # -f (function scope): -l here would be block-scoped to the if and
        # gone before `command opencode` runs.
        set -fx OPENCODE_CONFIG $corp
    end
    command opencode $argv
end

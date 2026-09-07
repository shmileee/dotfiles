function _source_cached_init --description "Cache a tool's shell init script and source it"
    set --local tool $argv[1]
    command -q $tool; or return 0

    # The cache key must cover every input the generated script depends on: a
    # stale script is a silent correctness bug, not merely a slow startup.
    #
    #   * resolved binary path - direnv bakes its own absolute path into the
    #     hook it emits, so a relocated binary (Homebrew prefix change,
    #     reinstall) must invalidate. An mtime check cannot observe a move.
    #   * fish version - zoxide's init copies fish's internal `cd` and refers
    #     to $__fish_data_dir, so a fish upgrade must invalidate.
    #
    # Both inputs come from builtins, so keying on them costs no subprocess
    # (~0.05ms). The mtime check then covers in-place binary upgrades.
    #
    # Only cache generators whose output is a pure function of these inputs.
    # `mise activate` is not one: its output embeds the invoking shell's PATH
    # and mise session state, so it must run live. See conf.d/mise-activate.fish.
    set --local resolved (command -v $tool)
    set --local key (string replace --all --regex '[^A-Za-z0-9._-]' _ -- "$resolved-$version")
    # Normalized because the cleanup loop below compares this path against glob
    # output, and fish normalizes globs while plain concatenation does not: a
    # trailing or doubled slash in XDG_CACHE_HOME would otherwise make the two
    # differ and delete the entry that was just written.
    set --local cache (path normalize $XDG_CACHE_HOME/fish/$tool-init-$key.fish)

    if not test -f "$cache"; or test "$resolved" -nt "$cache"
        mkdir -p (dirname $cache)
        if $argv[2..] >$cache.new
            mv $cache.new $cache
            # Drop variants left by an older binary path or fish version. Runs
            # only on the cold path; an unmatched glob is a no-op in fish.
            for stale in $XDG_CACHE_HOME/fish/$tool-init*.fish
                test (path normalize $stale) = "$cache"; or rm -f $stale
            end
        else
            rm -f $cache.new
            return 1
        end
    end
    source $cache
end

function _source_cached_init --description "Cache a tool's shell init script and source it"
    set --local tool $argv[1]
    command -q $tool; or return 0

    # A stale cached script is a silent correctness bug, so the key covers
    # every input: direnv bakes its own absolute path into the hook it emits
    # (an mtime check cannot observe a move), and zoxide's init refers to
    # $__fish_data_dir, so a fish upgrade must invalidate too. The mtime check
    # below then covers in-place upgrades.
    #
    # Only cache generators whose output is a pure function of those inputs;
    # `mise activate` embeds live PATH and session state. See mise-activate.fish.
    set --local resolved (command -v $tool)
    set --local key (string replace --all --regex '[^A-Za-z0-9._-]' _ -- "$resolved-$version")

    # Normalized because the cleanup loop compares this against glob output,
    # which fish normalizes: a doubled slash in XDG_CACHE_HOME would otherwise
    # make the two differ and delete the entry just written.
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

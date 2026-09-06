function _source_cached_init --description "Cache a tool's shell init script and source it"
    set --local tool $argv[1]
    command -q $tool; or return 0

    # Regenerate when the binary is newer than the cache. If a package manager
    # preserves old mtimes on upgrade, delete the cache file to force it.
    set --local cache $XDG_CACHE_HOME/fish/$tool-init.fish
    if not test -f "$cache"; or test (command -v $tool) -nt "$cache"
        mkdir -p (dirname $cache)
        if $argv[2..] >$cache.new
            mv $cache.new $cache
        else
            rm -f $cache.new
            return 1
        end
    end
    source $cache
end

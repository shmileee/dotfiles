function projects-fzf --description="fzf ghq jumper"
    # Worktrees (<repo>-worktrees/<task>) are reachable via their tmux windows;
    # only mainline checkouts belong in the jumper.
    set --local selected (ghq list | grep -v -- '-worktrees/' | fzf)
    set --local root (ghq root)

    if test -n "$selected"; and test -d "$root/$selected"
        cd "$root/$selected" || return
    end

    commandline --function repaint
end

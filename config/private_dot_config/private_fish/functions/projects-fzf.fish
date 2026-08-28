function projects-fzf --description="fzf ghq jumper"
    set --local selected (ghq list | fzf --height 40% --reverse)
    set --local root (ghq root)

    if test -n "$selected"; and test -d "$root/$selected"
        cd "$root/$selected" || return
    end

    commandline --function repaint
end

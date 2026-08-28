function t --description="Open a directory or file"
    if test (count $argv) -eq 1; and test -d "$argv[1]" -o "$argv[1]" = -
        cd "$argv[1]" || return
        ls
    else if test (count $argv) -eq 0
        cd "$HOME" || return
    else if test -f "$argv[1]"; or test ! -e "$argv[1]"; or test (count $argv) -gt 1
        $EDITOR $argv
    else
        printf "t: case not accounted for\n" >&2
        return 1
    end
end

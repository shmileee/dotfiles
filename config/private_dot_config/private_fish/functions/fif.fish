function fif --description="Using ripgrep combined with preview"
    if test (count $argv) -lt 1; or test $argv[1] = --help
        printf "Need a string to search for.\n"
        return 1
    end

    rg --files-with-matches --no-messages "$argv[1]" | fzf --preview \
        "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' \
     --ignore-case --pretty --context 10 '$argv[1]' || rg --ignore-case \
     --pretty --context 10 '$argv[1]' {}" | xargs -o nvim
end

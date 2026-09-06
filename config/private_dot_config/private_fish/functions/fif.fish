function fif --description "Find in files: ripgrep + fzf preview"
    if test (count $argv) -lt 1; or test "$argv[1]" = --help
        printf "Need a string to search for.\n" >&2
        return 1
    end

    command rg --files-with-matches --no-messages -- "$argv[1]" | fzf --preview \
        "command rg --ignore-case --pretty --context 10 -- '$argv[1]' {}" | xargs -o nvim
end

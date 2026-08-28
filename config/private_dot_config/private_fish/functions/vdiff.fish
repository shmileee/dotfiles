function vdiff --description="Compare two files or dirs with vim"
    if test (count $argv) -ne 2; or test "$argv[1]" = --help
        printf "vdiff requires two arguments\n"
        printf "  comparing dirs:  vdiff dir_a dir_b\n"
        printf "  comparing files: vdiff file_a file_b\n"
        return 1
    end

    set --local left "$argv[1]"
    set --local right "$argv[2]"

    if test -d "$left"; and test -d "$right"
        nvim +"DirDiff $left $right"
    else
        nvim -d "$left" "$right"
    end
end

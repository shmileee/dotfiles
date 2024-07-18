function fif --description="Using ripgrep combined with preview"
    if test (count $argv) -lt 1; or test $argv[1] = --help
        printf "Need a string to search for."
    else if test (count $argv) -eq 1
        rg --files-with-matches --no-messages "$argv[1]" | fzf --preview \
            "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' \
         --ignore-case --pretty --context 10 '$argv[1]' || rg --ignore-case \
         --pretty --context 10 '$argv[1]' {}" | xargs -o lvim
    end
end

function vdiff --description="Compare two files or dirs with vim"
    if test (count $argv) -ne 2; or test $argv[1] = --help
        printf "vdiff requires two arguments"
        printf "  comparing dirs:  vdiff dir_a dir_b"
        printf "  comparing files: vdiff file_a file_b"
    else
        set --local left "$argv[1]"
        set --local right "$argv[2]"

        if [ -d "$left" ] && [ -d "$right" ]
            lvim +"DirDiff $left $right"
        else
            lvim -d "$left" "$right"
        end
    end
end

function sudo
    if test "$argv" = !!
        eval command sudo $history[1]
    else
        command sudo $argv
    end
end

# export vault token
function vault_auth
    set --local env "$argv[1]"
    set -gx VAULT_ADDR https://$env.vault.tuadm.net:8200
    set -gx TF_VAR_vault_token_$env (vault login -method=oidc -path=okta role=admin -format=json 2>/dev/null | jq '.auth.client_token' -r)
end

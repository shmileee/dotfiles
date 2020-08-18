#!/usr/bin/env fish

alias s subl
alias g git
alias r 'source ~/.config/fish/config.fish'
alias p 'cd ~/projects'
alias w 'cd ~/work'
alias d 'cd ~/dotfiles'
alias tree 'tree -a -I ".git|*.pyc|*pycache*"'

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/esolidarity/google-cloud-sdk/path.fish.inc' ]; . \
    '/Users/esolidarity/google-cloud-sdk/path.fish.inc'; end

# Source corporate proxy if exists
if [ -f ~/.proxy ]; . \
   ~/.proxy; end

set -gx GOPATH ~/go
set -gx GOBIN "$GOPATH/bin"
set -gx PATH "$GOBIN" $PATH

function fif --description="Using ripgrep combined with preview"
    if test (count $argv) -lt 1; or test $argv[1] = "--help"
        printf "Need a string to search for."
    else if test (count $argv) -eq 1
        rg --files-with-matches --no-messages "$argv[1]" | fzf --preview \
            "rg  --ignore-case --pretty --context 10 '$argv[1]'"
    end
end

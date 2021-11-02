#!/usr/bin/env fish

# disable fish greeting
set --erase fish_greeting

switch (uname)
    case Darwin
        eval (brew shellenv)
end

if not functions -q fundle
    eval (curl -sfL https://git.io/fundle-install)
end

#######################################################################
#                               Plugins                               #
#######################################################################

zoxide init fish | source

fundle plugin edc/bass
fundle plugin FabioAntunes/fish-nvm
fundle plugin franciscolourenco/done
fundle init

#######################################################################
#                            Abbreviations                            #
#######################################################################

alias g git
alias ls exa
alias tx tmuxinator
alias du dust
alias df duf
alias vim nvim
alias r ranger

alias p 'cd ~/projects'
alias w 'cd ~/work'
alias d 'cd ~/dotfiles'

alias rg 'rg --hidden --follow --glob "!.git"'
alias ssh 'assh wrapper ssh --'
alias gdc 'git diff --cached | vim -'
alias tree 'tree -a -I ".git|*.pyc|*pycache*"'

alias tfcost 'terraform state pull \
   | curl -s -X POST -H "Content-Type: application/json" \
   -d @- https://cost.modules.tf/'

alias vss="sort -u ~/.vim/spell/en.utf-8.add \
   -o ~/.vim/spell/en.utf-8.add"

alias cdp 'cd (git rev-parse --show-toplevel)'
alias vdt="rm /tmp/%*"                                                # Remove Vim's temp file

abbr dps 'docker ps'                                                  # Get container process
abbr dpa 'docker ps -a'                                               # Get process included stop container
abbr dip 'docker inspect --format "{{ .NetworkSettings.IPAddress }}"' # Get container IP
abbr dkd 'docker run -d -P'                                           # Run deamonized container, e.g., $dkd base /bin/echo hello
abbr dki 'docker run -i -t -P'                                        # Run interactive container, e.g., $dki base /bin/bash
abbr dex 'docker exec -i -t'                                          # Execute interactive container, e.g., $dex base /bin/bash
abbr groot 'git rev-parse --show-toplevel'

#######################################################################
#                               Exports                               #
#######################################################################

set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

set -gx EDITOR nvim
set -gx FZF_DEFAULT_COMMAND "rg --files --hidden --follow --glob '!.git'"
set -gx FZF_DEFAULT_OPTS "--color=dark"
set -gx FZF_CTRL_T_COMMAND "rg --files --hidden --follow --glob '!.git'"

set -gx GOPATH ~/go
set -gx GOBIN "$GOPATH/bin"

fish_add_path $GOBIN
fish_add_path ~/.local/bin
fish_add_path ~/bin

set -gx DISPLAY :0

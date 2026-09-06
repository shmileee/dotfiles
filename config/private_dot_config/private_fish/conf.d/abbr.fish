# set up abbreviations

status is-interactive; or return

abbr g git
abbr c clear
abbr lg lazygit
abbr dps 'docker ps'
abbr dpa 'docker ps -a'
abbr dex --set-cursor 'docker exec -it % bash'
# Docker cleanup (replaces the old dstop/drm/drmf/drmi functions; abbrs expand
# visibly, and the prune commands ask for confirmation).
abbr dstop 'docker stop (docker ps -q)'
abbr drm 'docker container prune'
abbr drmf 'docker rm -f (docker ps -aq)'
abbr drmi 'docker image prune -a'
abbr groot 'git rev-parse --show-toplevel'
abbr gho 'gh browse'
abbr gdc 'git diff --cached | vim -'
abbr cdp 'cd (git rev-parse --show-toplevel)'

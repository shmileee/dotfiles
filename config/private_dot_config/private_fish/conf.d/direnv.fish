# set up direnv

status is-interactive; or return

if type -q direnv
    direnv hook fish | source
end

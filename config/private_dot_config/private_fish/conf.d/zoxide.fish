# set up zoxide

status is-interactive; or return

if type -q zoxide
    zoxide init fish | source
end

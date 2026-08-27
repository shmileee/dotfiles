status is-interactive; or return

if type -q fzf_configure_bindings
    fzf_configure_bindings --directory=\ct
end

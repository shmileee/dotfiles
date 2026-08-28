status is-interactive; or return

bind \u0137 backward-word
bind \u0142 forward-word

# Alt-S visibly prepends sudo; unlike history expansion, it never evals text.
function prepend-sudo-to-commandline
    set --local command (commandline)
    string match --quiet --regex '^\s*sudo\s' -- "$command"; or commandline "sudo $command"
end

bind \es prepend-sudo-to-commandline
bind \cG projects-fzf

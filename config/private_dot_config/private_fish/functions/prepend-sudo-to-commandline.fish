# Alt-S visibly prepends sudo; unlike history expansion, it never evals text.
function prepend-sudo-to-commandline --description "Prepend sudo to the command line"
    set --local command (commandline)
    string match --quiet --regex '^\s*sudo\s' -- "$command"; or commandline "sudo $command"
end

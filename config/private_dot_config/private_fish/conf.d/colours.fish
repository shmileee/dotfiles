# set up dircolors

status is-interactive; or return

if type -q gdircolors
    gdircolors -c $HOME/.config/dircolors/.dircolors | source
end

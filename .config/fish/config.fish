eval (python3 -m virtualfish compat_aliases)
alias s subl
alias g git
alias r 'source ~/.config/fish/config.fish'
alias p 'cd ~/Projects'

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/esolidarity/google-cloud-sdk/path.fish.inc' ]; . '/Users/esolidarity/google-cloud-sdk/path.fish.inc'; end

set -gx GOPATH "/Users/esolidarity/go"
set -gx GOBIN "$GOPATH/bin"
set -gx PATH "$GOBIN" $PATH

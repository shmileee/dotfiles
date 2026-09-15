# k9s: the tokyonight_moon skin against the ephemeral kind cluster.
#
# $KUBECONFIG and $K9S_CONFIG_DIR are exported by render.sh and point into the
# sandbox, so the only context that exists during the recording is
# kind-dotfiles-demo. sandbox.sh check fails the render if that is ever untrue.
# Sourced by demo.tape.

# prefix } -> next-window (the 'cluster' window)
Ctrl+A
Type "}"
Sleep 1200ms

Type "k9s"
Enter
# k9s has to finish discovery and open its first watch before it reacts to
# keys, and against a fresh kind cluster that takes a variable few seconds.
# Waiting on the view title is both quicker and steadier than guessing.
Wait+Screen /pods\(/
Sleep 1500ms

# 0 -> all namespaces; the demo workloads live in storefront, payments and
# observability rather than default.
Type "0"
Wait+Screen /Running/
Sleep 1500ms
Down 4
Sleep 1500ms

Type ":deploy"
Enter
Sleep 3500ms
Down 2
Sleep 1500ms

Type ":svc"
Enter
Sleep 2500ms

Escape
Sleep 800ms

Type ":q"
Enter
Sleep 600ms

# Global agent rules

Applies to every opencode session on this machine. Project `AGENTS.md` files
are loaded in addition to this one, not instead of it.

## mise-managed environment

Per-directory environment comes from mise `[env]` blocks, injected by a shell
hook that only runs in **interactive** shells. Agent tool calls are
non-interactive, so they never receive it — `fish -c` included.

Wrap anything that depends on per-directory environment:

```sh
mise exec -- <command>       # preferred
eval "$(mise env -s bash)"   # alternative: once per shell, after cd
```

### gh

`gh` picks its account from `GH_TOKEN`, which mise sets per directory tree.
Without it, `gh` silently falls back to the globally active account, so
`gh pr create` in a personal repo can open the PR under the wrong identity.
There is no error — just the wrong author. Always run `mise exec -- gh ...`.

`git` needs no wrapper: identity, signing key and SSH key all resolve from
config rather than environment.

# Dotfiles (chezmoi source repo)

Personal dotfiles managed with **chezmoi**. `.chezmoiroot` is `config/`, so the
chezmoi source state lives under `config/` and maps to `$HOME`:

*   `config/private_dot_config/<name>/...` → `~/.config/<name>/...`
*   chezmoi source naming applies: `private_` = permission 0600/0700, `dot_` =
    leading dot.

## Hard rules

*   **Never edit deployed targets in `$HOME` directly** (e.g.
    `~/.config/opencode/opencode.json`). Edit the source file in this repo, then
    run `chezmoi apply`. Editing targets directly causes silent drift; check
    with `chezmoi diff` / `chezmoi status`.
*   **Never commit secrets.** Secrets live outside this repo (e.g.
    `~/.config/opencode/secrets/`, referenced via `{file:...}` interpolation).
    Corp-specific config (`~/.config/opencode/opencode.corp.json`, loaded via
    `OPENCODE_CONFIG` in fish) intentionally stays local and unmanaged.
*   `*.tmpl` files are chezmoi templates — preserve template syntax when
    editing.

## Formatting / checks

*   Pre-commit hooks are configured (`.pre-commit-config.yaml`) and run with
    **prek** (mise-managed, drop-in pre-commit replacement — do not use
    `pre-commit` itself): run `prek run --files <changed files>` before
    committing.

## Commit signing

Commits here are signed with an SSH key held in 1Password, through
`op-ssh-sign` as `gpg.ssh.program` (configured in `~/.config/git/personal`).
This needs no environment setup: that binary exists precisely so `SSH_AUTH_SOCK`
does not have to be set, and it derives 1Password's agent socket itself when the
variable is absent.

What it does need is an approval an agent cannot give. 1Password asks for Touch
ID whenever its authorization has lapsed, and a non-interactive tool call cannot
answer it. The commit then either fails as

```text
error: 1Password: failed to fill whole buffer
fatal: failed to write commit object
```

or hangs until the tool's own timeout. Neither symptom names the prompt, and
both read like a git or signing-config fault.

*   **Never disable signing to get past this.** `--no-gpg-sign`, `-c
    commit.gpgsign=false` and setting `SSH_AUTH_SOCK` all appear to work and all
    bury the cause.
*   Approve the prompt and rerun the identical `git commit`; there is nothing to
    fix in the command.
*   If no prompt arrives, 1Password is locked or not running. Report that and
    stop — it needs the user, not a workaround.

Verify that a commit was signed, not merely created:

```sh
git log -1 --format='%G? %GS'
```

`G` = good signature. `U` = signed, but the signer is missing from
`gpg.ssh.allowedSignersFile`. `N` = not signed at all, i.e. the failure above
was silently worked around.

## Layout

*   `config/` — chezmoi source state (the actual dotfiles)
*   `bootstrap/` — Ansible-based machine bootstrap
*   `docs/`, `site/` — documentation site content
*   `tests/`, `Dockerfile` — containerized testing of the setup

## Test isolation and live resources

Existing terminal sessions, running applications, service instances, and
deployed configuration are live user resources. Git worktrees share these
resources with the rest of the machine.

*   Run tests against disposable resources owned by the test: temporary
    directories, dedicated sockets and ports, and separately started processes.
*   Use minimal test configuration. Load user configuration or plugins into
    an isolated test instance only when needed for the behavior under test.
*   Keep every command and subprocess explicitly targeted at the test's
    resources. Avoid defaults that could select a live instance.
*   Give potentially blocking commands a timeout. Arrange cleanup before
    starting the test, and clean up only resources that the test created.
    Avoid broad process-name kills.
*   When isolation is unavailable, run the remaining safe checks and report
    what remains unverified. Do not substitute the user's live environment.
*   Read-only diagnosis of live resources is allowed. Changes to live
    resources must follow the user's task and remain narrowly scoped;
    permission to implement a feature does not imply permission to experiment
    on unrelated running sessions.

### tmux tests

*   Start a disposable server with a unique `-S` socket or `-L` name and
    `-f /dev/null`. Specify that socket on every command, including cleanup
    and commands launched by helper scripts.
*   Never attach a client from a pane owned by the same server. Never unset
    `TMUX` to bypass that nesting check.
*   For popup or interactive tests, attach through a separate terminal
    controlled by the test harness and continuously consume its output.
*   Exercise the actual behavior under test, assert the result, and terminate
    only the test's client and server.
*   Test-session names alone do not provide isolation from the live server.

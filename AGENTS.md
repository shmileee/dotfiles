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

## Layout

*   `config/` — chezmoi source state (the actual dotfiles)
*   `bootstrap/` — Ansible-based machine bootstrap
*   `docs/`, `site/` — documentation site content
*   `tests/`, `Dockerfile` — containerized testing of the setup

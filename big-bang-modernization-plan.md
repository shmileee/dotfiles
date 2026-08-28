# Dotfiles modernization plan

> Updated: 2026-08-28
>
> Repository baseline: `master` at `14b1bdf`
>
> Scope: the current repository, not the former `codex/dotfiles-refresh` branch

## 1. Outcome

The recent refresh is already merged. The repository now applies the current
checkout, handles an empty Fisher installation, uses current Ansible facts, and
has materially better macOS idempotence. Those are the baseline, not future
work.

The next modernization should be a focused reliability pass with four goals:

1. A normal run may naturally refresh managed software, while cleanup and
   destructive removal remain explicit.
2. Neovim and the most important bootstrap inputs are repeatable enough to
   recover a working machine.
3. Pull requests test the same paths that publish the Docker image and configure
   macOS.
4. Known security and terminal correctness problems are removed.

“Big bang” describes the desired end state, not the delivery method. Implement
the work below as small, independently reversible changes.

## 2. Current repository state

### Already complete — preserve it

- `scripts/setup.sh` defaults to `--all`, detects the current checkout, cleans up
  its temporary checkout, and discovers Homebrew across supported prefixes.
- The dotfiles role applies `config/` from the current checkout rather than
  silently applying remote `master`.
- Ansible roles use `ansible_facts[...]` and the latest changes make Fisher,
  keyboard mappings, and diagnostics idempotent.
- Fish interactive setup is guarded, and mise activation has its own `conf.d`
  file.
- The macOS workflow runs for relevant pushes, not only the default branch.
- Pre-commit includes ShellCheck, yamllint, and ansible-lint.
- Docker BuildKit secrets are used instead of copying the GitHub token into the
  image.
- Go and Node runtime installation is owned by mise rather than duplicate
  Ansible roles.

### Verified gaps

| Priority | Current behavior | Desired result |
|---|---|---|
| P0 | Git config uses `credential.helper = store` | Use the macOS keychain; define an explicit Linux fallback instead of plaintext storage. |
| P0 | `lazy-lock.json` is absent while Lazy uses moving plugin commits | Commit the lockfile and restore it during provisioning. |
| P0 | Docker CI builds and immediately publishes `latest` on `master`, with no behavioral assertions | Build and smoke-test on pull requests; publish only after the same checks pass on `master`. |
| P0 | Routine Ansible runs mixed useful updates with destructive apt cleanup | Keep normal tool updates, but remove `autoremove` and `autoclean` from setup. |
| P1 | macOS idempotence is manual-only; normal macOS CI does not run a second pass | Add a second-pass assertion to the normal macOS workflow or share one reusable test path. |
| P1 | Ansible collections are installed by name and considered valid merely when directories exist | Add a small versioned requirements file and always install from it. |
| P1 | Global Fish config exports `GODEBUG=asyncpreemptoff=1` | Remove it unless a currently reproducible program-specific problem still needs it. |
| P1 | tmux sets `default-terminal` to `xterm-256color` | Advertise `tmux-256color` inside tmux and keep a documented compatibility fallback if needed. |
| P2 | TPM itself tracks `master`; Fisher is downloaded from `main` | Use a reviewed release or commit for the installer/manager only. Plugins may remain intentionally rolling. |
| P2 | Several old macOS defaults and the screenshot path are questionable | Test the settings on the actually supported macOS version and remove ineffective entries. |
| P2 | Documentation describes older behavior and a single central version source | Update it after behavior stabilizes. |

## 3. Scope and ownership

Keep the existing architecture. A migration to Nix, a second package manifest,
or a new task framework is not required.

| Layer | Owns |
|---|---|
| `setup.sh` | Minimal bootstrap: OS prerequisites, Homebrew, Ansible entry point |
| Ansible | OS packages, applications, default shell, macOS settings, orchestration |
| chezmoi | Files below the home directory and machine-specific templates |
| mise | Developer runtimes and developer CLI versions |
| Fisher/TPM/Lazy | Fish, tmux, and Neovim plugins respectively |
| GitHub Actions | Static checks, integration tests, and Docker publication |

Only support targets that are exercised in practice:

- Apple Silicon macOS is the primary workstation target.
- Ubuntu 24.04 ARM64 is the container/integration target.
- Other Debian-family and x86-64 hosts are best effort unless a real user or CI
  job is added for them.
- Non-interactive Fish must start without output or terminal side effects.

## 4. Phase 1 — keep update ownership simple

Ansible may bring an older machine forward. It does not need to pretend that a
six-month-old run is risk-free.

### 4.1 Use native update workflows

Keep `./scripts/setup.sh --all` straightforward:

- Homebrew may refresh metadata and upgrade the formulae and greedy casks
  declared in Ansible as part of a normal run.
- A full `brew upgrade` for software outside the Ansible manifest remains a
  direct user command rather than a separate Ansible upgrade mode.
- Renovate proposes changes to versions declared in mise, GitHub Actions, and
  other supported manifests.
- Lazy, Fisher, and TPM retain their native update commands and review flows.
- Remove `autoremove` and `autoclean` from setup because removing packages is
  cleanup, not a natural update.
- Do not add a repository-wide `--upgrade` flag or Ansible variable that couples
  unrelated package managers.

### 4.2 Keep the chezmoi source authoritative

The current checkout remains the source of truth. Continue using
`chezmoi apply --force`: edits made only to generated target files are unmanaged
drift and may be overwritten. Intentional changes must first be imported into
the chezmoi source.

- After apply, use one lightweight postcondition (`chezmoi verify` if the
  current templates support it, otherwise `chezmoi status`). Do not add a chain
  of redundant `doctor`, `verify`, `status`, and `diff` checks.

### 4.3 Remove the global Go runtime override

Delete `GODEBUG=asyncpreemptoff=1` from the global Fish template. If one tool
still needs it, put it in that tool’s wrapper with a comment explaining the
failure and removal condition.

## 5. Phase 2 — restore useful repeatability

The goal is repeatable recovery, not cryptographic verification of every
download.

### 5.1 Restore the Neovim lockfile

This is the only missing lockfile that currently blocks reliable restoration of
a complex working configuration.

- Generate and commit `config/private_dot_config/nvim/lazy-lock.json` through
  chezmoi.
- Provision with Lazy’s restore/sync behavior against the committed lockfile.
- Run plugin updates through Lazy, review the lockfile diff, and commit it.
- Keep `version = false`; the lockfile, rather than plugin release tags, records
  the working graph.
- Add one headless startup check after provisioning. Do not require an offline
  test, exhaustive health parsing, or startup benchmarks unless failures justify
  them.

### 5.2 Use a pragmatic mise version policy

The current file mixes exact versions, major/minor channels, and `latest`.
Normalize it deliberately:

- Use exact versions for core runtimes used to run the environment: Go, Node,
  Python, Ruby, and Neovim.
- Major/minor channels are acceptable for tools where automatic compatible
  updates are intentional.
- Replace bare `latest` with an explicit channel or version for tools required by
  CI (`prek`, ShellCheck, shfmt, and ansible-lint dependencies).
- Leave convenience tools rolling only when breakage is cheap and the choice is
  documented next to the entry.

Do not make a mise lockfile a prerequisite for this modernization. Revisit it
only if exact entries still resolve differently across real supported targets.

### 5.3 Version Ansible collections

Add `scripts/common/ansible/requirements.yml` with compatible versions for
`community.general` and `ansible.posix`. Install from that file every time;
Ansible Galaxy will handle already-satisfied versions.

Pinning the collection version is sufficient. Do not add manual archive
checksums or signature verification.

### 5.4 Limit immutable pins to executable control points

Use reviewed immutable versions where a small pin controls code that executes
during setup or CI:

- Third-party GitHub Actions.
- The Fisher installer.
- TPM itself.
- The existing `fish-async-prompt` compatibility pin, until its workaround is
  no longer needed.

Do not pin every Fish/tmux plugin commit. Use Fisher and TPM directly when an
intentional plugin refresh is wanted.

Do not add checksum/signature handling for the Homebrew installer, the repository
bootstrap tarball, Git clones, or every GitHub release asset. HTTPS plus a
reviewed upstream and a recoverable dotfiles workflow is proportionate for this
personal repository. If the threat model changes, revisit this decision once at
the bootstrap boundary rather than implementing bespoke verification in every
role.

Keep `ubuntu:24.04` as a moving patch-level base so rebuilds receive security
updates. A digest pin would work against that goal unless an automated refresh
process is also maintained.

## 6. Phase 3 — make CI prove behavior

### 6.1 Add a fast pull-request validation job

Run the checks already represented by repository tooling:

- `prek run --all-files` (which covers ShellCheck, yamllint, and ansible-lint).
- `ansible-playbook --syntax-check`.
- `fish -n` for managed Fish files/templates after rendering.
- `nvim --headless +qa` after plugin restoration in integration testing.

Add `actionlint` or `hadolint` only if they catch a current problem or can be
installed without creating another duplicated toolchain. Avoid a long checklist
of formatters and scanners that no contributor runs locally.

### 6.2 Test Docker before publishing

Refactor `.github/workflows/docker.yaml` so pull requests affecting Docker,
scripts, or config:

1. Build the ARM64 image without pushing.
2. Start a container and assert a short behavioral contract:
   - expected non-root user and home;
   - Fish, Homebrew, chezmoi, tmux, mise, and Neovim execute;
   - non-interactive Fish emits no unexpected output;
   - headless Neovim starts;
   - a second Ansible run has no unexpected changes.
3. On `master`, publish only after those assertions pass.

Publish both a commit-SHA tag and the convenience `latest` tag. Do not add SBOM,
provenance, signing, or multi-architecture publication in this pass; none of
them improves the plan’s primary goal of proving that the workstation image
works.

### 6.3 Consolidate macOS validation

The current `macos.yaml` and manual `idempotence.yaml` duplicate destructive
Homebrew cleanup and installation logic.

- Keep one normal macOS validation path for relevant branch pushes.
- After installation, run pre-commit and a second Ansible pass, asserting
  `changed=0`.
- Keep manual destructive “clean runner” testing only if it finds failures that
  the normal hosted runner path misses. Otherwise delete the duplicate workflow.
- Add explicit minimal permissions, a timeout, and concurrency cancellation to
  the surviving workflows.

Do not create Intel macOS, Linux x86-64, scheduled, or large matrix jobs until
those targets are genuinely supported.

## 7. Phase 4 — fix concrete shell, terminal, and macOS issues

### 7.1 Fish

- Keep the `fish-async-prompt` commit pin and add a short comment explaining why
  it exists. A dedicated pipeline-status regression harness is optional; add it
  only if that bug recurs.
- Keep interactive-only work behind `status is-interactive`.
- Add `VISUAL=nvim` alongside `EDITOR`.
- Keep `fzf_fd_opts`; remove `FZF_DEFAULT_COMMAND` if it duplicates or conflicts
  with `fzf.fish` during manual testing.
- Guard Docker helper functions against empty container/image lists.
- Replace the `sudo !!` implementation if it uses `eval`; insert the visible
  command line instead.
- Split `conf.d/functions.fish` into autoloaded functions only as a maintainability
  cleanup. Do not claim a performance win without measuring one.

### 7.2 tmux and Alacritty

- Set tmux `default-terminal` to `tmux-256color` and use `terminal-features` for
  RGB where the installed tmux supports it.
- Test `infocmp tmux-256color` on the workstation and over the SSH hosts actually
  used. Retain a documented fallback if those hosts lack the entry.
- Remove Alacritty’s forced `TERM=xterm-256color` if Alacritty already provides
  the correct value.
- Add `bind C-a send-prefix` for nested sessions if nested tmux is used.
- Do not redesign clipboard handling, launch tmux directly from Alacritty, or
  tune status-line refresh without a demonstrated problem.

### 7.3 macOS defaults

Review the current defaults on the primary macOS version and make only observed
fixes:

- Create `~/Pictures/Screenshots` and pass an expanded path before setting the
  screenshot location.
- Remove obsolete Dashboard and other ineffective defaults.
- Resolve the duplicate `auto-open-ro-root` entries with different descriptions.
- Keep the new keyboard mapping implementation and its idempotence behavior.
- Compare Dock state before rebuilding it, but do not build a general backup and
  rollback system for preference keys.

## 8. Documentation and maintenance

After the behavior changes land, update the README and docs to describe:

- the two supported targets;
- how normal setup and tool-native updates interact;
- current-checkout behavior for local development;
- how Neovim plugin updates change `lazy-lock.json`;
- where OS packages, mise tools, and plugins are declared;
- the non-plaintext Git credential setup;
- how to run the same validation locally that CI runs.

Use Renovate for dependencies it already understands. Add a custom manager only
for a dependency that otherwise becomes demonstrably stale; do not maintain a
generated inventory or regex manager for every URL.

## 9. Delivery order

### Change 1 — simplify update behavior

- Remove routine apt cleanup.
- Keep normal Homebrew update behavior.
- Use Renovate and tool-native commands instead of a custom upgrade path.
- Remove global `GODEBUG`.

### Change 2 — restore the working editor state

- Commit `lazy-lock.json`.
- Restore rather than update plugins during provisioning.
- Add the headless startup assertion.

### Change 3 — fix credentials and dependency control points

- Replace `credential.helper = store`.
- Add Ansible collection requirements.
- Pin Fisher and TPM themselves.
- Normalize mise versions required by CI.

### Change 4 — make CI behavioral

- Add PR validation.
- Build and smoke-test Docker before publication.
- Add macOS second-pass idempotence and remove duplicated workflow logic.

### Change 5 — terminal and macOS cleanup

- Correct tmux/Alacritty TERM handling.
- Apply the targeted Fish and macOS fixes.
- Update documentation.

## 10. Definition of done

- [ ] A fresh Apple Silicon macOS workstation completes setup.
- [ ] The Ubuntu 24.04 ARM64 image builds and passes behavioral smoke tests.
- [ ] A second Ansible run reports no unexpected changes.
- [x] Ansible check mode reports drift without mutating command-backed state.
- [x] Normal setup may update managed software but does not run apt cleanup.
- [x] Neovim restores the committed plugin graph and starts headlessly.
- [x] Git credentials are not written to `~/.git-credentials` in plaintext.
- [x] Chezmoi force-applies the reviewed current checkout as the source of truth.
- [x] Non-interactive Fish starts silently.
- [x] `TERM` describes Alacritty outside tmux and tmux inside it.
- [x] Ansible collections and executable installer/manager control points have
      reviewed versions.
- [x] Local and CI validation share the repository’s pre-commit configuration.
- [x] Documentation matches the resulting setup and native update workflows.

## 11. Independent review result

A second pass challenged every item by asking: does this prevent a failure seen
in the current repository, reduce routine surprise, or make recovery materially
easier? If not, it was removed or deferred.

The following ideas from the previous plan are intentionally out of scope:

- Checksums or signature verification for every download.
- A mise lockfile before exact versions prove insufficient.
- Pinning every shell, tmux, and editor dependency independently of its native
  lock/update workflow.
- A Docker base digest, SBOM, provenance, or image signing for this personal
  workstation image.
- Broad Intel/macOS/Linux matrices and scheduled benchmark jobs.
- Startup performance budgets before a measured performance problem exists.
- ADRs, generated dependency inventories, and a large mise task catalog.
- A Brewfile alongside the existing Ansible package manifest.
- A repository-wide upgrade command and Ansible upgrade-mode variable.
- General macOS defaults backups, rollback machinery, and extensive version
  gating.
- Exhaustive preflight, offline, secret-scanning, and disaster-recovery suites.

These can be reconsidered if the repository becomes a shared distribution,
handles higher-value secrets, supports more machines, or starts exhibiting the
specific failures they address. For the current repository they would add more
maintenance surface than confidence.

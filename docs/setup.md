---
title: Setup guide
description: Review, install, customize, and reapply the workstation configuration.
tags:
  - Setup
  - macOS
  - Ubuntu
  - Ansible
  - chezmoi
  - mise
hide:
  - tags
---

# Set up a workstation

<p class="page-lead">Use the review-first path for an existing machine. The one-line installer is intended for a new machine or for a configuration you already trust.</p>

<nav class="setup-paths" aria-label="Choose an installation path" data-mobile-toc-anchor>
  <a href="#recommended-review-then-run">
    <span>Existing or customized machine</span>
    <strong>Review first</strong>
    <p>Clone the repository, inspect the configuration, and run the local checkout.</p>
  </a>
  <a href="#fast-path-bootstrap-a-new-machine">
    <span>Fresh or already trusted machine</span>
    <strong>Use the fast path</strong>
    <p>Run the hosted bootstrap and apply the complete configuration.</p>
  </a>
</nav>

<section class="context-help-source" hidden data-search-exclude>
<button class="context-help-trigger" type="button" aria-label="Open quick context" aria-controls="context-help" aria-haspopup="dialog" title="Quick context" data-context-open data-context-ui><span aria-hidden="true">?</span></button>
<dialog class="context-help" id="context-help" aria-labelledby="context-help-title" data-context-dialog data-context-ui>
<div class="context-help__panel">
<header class="context-help__header">
  <div><p>Quick context</p><h2 id="context-help-title" data-search-exclude>Terms used on this page</h2></div>
  <button type="button" aria-label="Close quick context" data-context-close><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="m4 4 8 8m0-8-8 8" /></svg></button>
</header>
<dl class="context-help__terms">
  <div><dt>Bootstrap</dt><dd>The small first step that downloads the repository and starts the setup.</dd></div>
  <div><dt>Playbook</dt><dd>The ordered Ansible plan that describes the desired workstation state.</dd></div>
  <div><dt>Role</dt><dd>A focused part of the playbook, such as configuring fish, tmux, or Neovim.</dd></div>
  <div><dt>Check mode</dt><dd>An Ansible preview that reports many expected changes without applying them.</dd></div>
  <div><dt>mise task</dt><dd>A named command for routine work after the initial setup has installed mise.</dd></div>
  <div><dt>Homebrew and apt</dt><dd>Package managers used to install software on macOS and Ubuntu.</dd></div>
  <div><dt>Docker image</dt><dd>A packaged Linux environment used to test the setup away from your machine.</dd></div>
</dl>
</div>
</dialog>
</section>

## Before you begin

The full setup can:

*   install apt packages, Homebrew packages, and macOS applications;
*   change your login shell to fish;
*   initialize chezmoi and force-apply files from this repository;
*   install tmux and Neovim plugins;
*   install Rancher Desktop on macOS; and
*   change macOS defaults, Dock contents, and keyboard shortcuts.

Back up your existing configuration before continuing. At minimum, inspect
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
and the files under
[`config/`](https://github.com/shmileee/dotfiles/tree/master/config).

### Platform requirements

=== "macOS"

    Install available system updates and the Xcode Command Line Tools on a
    fresh machine:

    ```bash
    sudo softwareupdate -i -a
    xcode-select --install
    ```

=== "Ubuntu"

    Use Ubuntu with a non-root account authorized to use the installed `sudo`
    command. The base installation must provide a POSIX shell, `curl`, `tar`,
    and standard shell utilities. Ansible installs Git, native apt
    prerequisites, and Homebrew.

Apple Silicon macOS and Ubuntu are the supported targets. Setup validates the
operating system before downloading sources or requesting elevated privileges.

## Recommended: review, then run

Clone the repository so you can inspect exactly what the setup will run. Pay
particular attention to
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
and the
[`main.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml)
playbook:

```bash
repository_url=https://github.com/OWNER/REPOSITORY.git
checkout="$HOME/ghq/personalgit/OWNER/REPOSITORY"
mkdir -p "$(dirname "$checkout")"
git clone "$repository_url" "$checkout"
cd "$checkout"

less scripts/common/ansible/config.yaml
less scripts/common/ansible/main.yaml
```

When you are comfortable with the configuration, run the complete setup:

```bash
./scripts/setup.sh
```

The local command is also the recovery path after a bootstrap that created the
checkout but did not finish. It builds a disposable locked Ansible controller
from this checkout and preserves all durable Ansible changes if a task fails.

## Fast path: bootstrap a new machine

```bash
curl -fsSL https://oponomarov.com/d | sh
```

`https://oponomarov.com/d` is the author's convenience redirect for installing
this repository on a fresh, trusted workstation. It redirects to
[`scripts/setup.sh`](https://github.com/shmileee/dotfiles/blob/master/scripts/setup.sh)
on the configured mutable branch. The POSIX loader stages that branch in a
private temporary workspace, downloads the pinned uv controller, and hands all
workstation changes to Ansible. The controller workspace is deleted on every
ordinary exit; uv's normal download cache is retained.

The command above keeps certificate verification enabled. A minimal Ubuntu
base without a CA bundle cannot validate even this first HTTPS request; only on
that base, fetch the loader with `curl -kfsSL https://oponomarov.com/d | sh`.
The loader detects the missing bundle and limits disabled verification to its
remaining pre-controller curl downloads and the pre-Ansible Galaxy collection
install. uv verifies the locked Python environment with its own trusted roots.
Ansible then installs and updates `ca-certificates`; the persistent Git clone
and every later download use normal certificate verification. macOS and Ubuntu
systems with an existing CA bundle never disable verification. No persistent
insecure setting is written.

??? "Download the script before running it"

    If you want the convenience of the bootstrap without piping directly into
    a shell:

    ```bash
    curl -fsSL https://raw.githubusercontent.com/shmileee/dotfiles/master/scripts/setup.sh > setup.sh
    less setup.sh
    chmod +x setup.sh
    ./setup.sh
    ```

## What setup does

<ol class="install-flow">
  <li>
    <span>01</span>
    <div>
      <strong>Validate the platform</strong>
      <p>Reject root, an invalid home, occupied fresh-install targets, and unsupported platforms before privileged work.</p>
    </div>
  </li>
  <li>
    <span>02</span>
    <div>
      <strong>Build the controller</strong>
      <p>Stage the configured repository branch, validate pinned uv, and synchronize the locked Python and Ansible project.</p>
    </div>
  </li>
  <li>
    <span>03</span>
    <div>
      <strong>Provision with Ansible</strong>
      <p>Install Ubuntu prerequisites and Git, create the persistent checkout, then install Homebrew and the configured workstation state.</p>
    </div>
  </li>
  <li>
    <span>04</span>
    <div>
      <strong>Hand off to mise</strong>
      <p>Prepare the persistent checkout for future updates with <code>mise run reconcile</code>.</p>
    </div>
  </li>
</ol>

## Recover or reconcile

<div class="setup-reference" markdown>

| Command | Purpose |
| --- | --- |
| `./scripts/setup.sh` | Bootstrap a workstation or recover a valid incomplete persistent clone. |
| `mise run reconcile` | Run normal ongoing reconciliation from a completed checkout. |
| `mise run reconcile:check` | Preview supported changes after bootstrap. |

</div>

The hosted one-line installer is for a new workstation. It stops if the derived
checkout path already exists and leaves that path untouched. For a valid
incomplete checkout, run `./scripts/setup.sh` from that checkout. After a
successful setup, use `mise run reconcile`; rerun the local setup script only if
the installed mise environment needs to be recovered.

!!! note "Check mode has limits"

    Ansible check mode is useful for file and package changes, but command-based
    tasks cannot always predict their effects. Treat it as a preview, not a full
    simulation.

## Customize the setup

Make changes in four places:

<div class="setup-reference setup-reference--three" markdown>

| Area | Source of truth | Typical changes |
| --- | --- | --- |
| Packages and applications | [`scripts/common/ansible/config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml) | Homebrew packages, casks, Dock items, keyboard shortcuts |
| System behavior | [`scripts/common/ansible/roles/`](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles) | Installation logic and macOS defaults |
| Home-directory files | [`config/`](https://github.com/shmileee/dotfiles/tree/master/config) | fish, Git, tmux, Neovim, Alacritty, OpenCode |
| Tool versions | [`config/private_dot_config/mise/config.toml`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/mise/config.toml) | Language runtimes and developer tools |

</div>

The `dotfiles.checkout` value in
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
points chezmoi at the persistent path derived from the configured repository
slug. The role force-applies that checkout's
[`config/`](https://github.com/shmileee/dotfiles/tree/master/config) directory,
so the source remains available after the temporary bootstrap controller is
removed.

### Reuse this repository as your own

The bootstrap repository identity has one source of truth: the settings at the
top of `scripts/setup.sh`. Before using a fork, update:

*   `repository_slug` to `OWNER/REPOSITORY`;
*   `repository_ref` if the default branch is not `master`; and
*   `bootstrap_url` to your own redirect, or to the raw setup script URL.

Setup derives the archive URL, HTTPS clone URL, and
`$HOME/ghq/personalgit/OWNER/REPOSITORY` path from those settings. Run
`./scripts/setup.sh --print-config` to inspect the effective values without
changing the machine.

Repository identity is only one part of adopting personal dotfiles. Also
review and replace these personal publication and user settings:

*   the public redirect itself, so it points to your slug and branch;
*   the Docker Hub identity in `.github/workflows/docker.yaml` if it differs
    from the GitHub repository owner and slug used by its defaults;
*   the `UBUNTU_ARM_RUNNER` GitHub Actions repository variable used by the
    Docker workflow;
*   the documentation domain in `mkdocs.yml`, `docs/robots.txt`,
    `.github/workflows/docs.yaml`, and `README.md`;
*   the repository file links throughout `README.md` and `docs/`, plus
    `repo_url`, `repo_name`, and `edit_uri` in `mkdocs.yml`;
*   Git author and namespace values under
    `config/private_dot_config/private_git/`; and
*   every package, application, secret template, shell preference, and macOS
    default under `scripts/common/ansible/config.yaml` and `config/`.

### Ansible roles

<div class="setup-reference" markdown>

| Role | Responsibility |
| --- | --- |
| [`bootstrap_prerequisites` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/bootstrap_prerequisites){ .role-link aria-label="bootstrap_prerequisites role on GitHub" } | Validate the platform, install Ubuntu prerequisites, and create or verify the persistent checkout |
| [`homebrew` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/homebrew){ .role-link aria-label="homebrew role on GitHub" } | Install Homebrew on macOS and Ubuntu |
| [`common` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/common){ .role-link aria-label="common role on GitHub" } | Install shared command-line tools and platform-specific packages and applications |
| [`fonts` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/fonts){ .role-link aria-label="fonts role on GitHub" } | Install developer fonts on macOS and Ubuntu |
| [`dotfiles` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/dotfiles){ .role-link aria-label="dotfiles role on GitHub" } | Install chezmoi and apply the current checkout |
| [`fish` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/fish){ .role-link aria-label="fish role on GitHub" } | Install fish, make it the login shell, and synchronize Fisher plugins |
| [`mise` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/mise){ .role-link aria-label="mise role on GitHub" } | Install the tools declared in the mise configuration |
| [`neovim` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/neovim){ .role-link aria-label="neovim role on GitHub" } | Install LazyVim and its plugins in headless mode |
| [`docker` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/docker){ .role-link aria-label="docker role on GitHub" } | Install Rancher Desktop on macOS |
| [`tmux` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/tmux){ .role-link aria-label="tmux role on GitHub" } | Install tmux, TPM, and declared plugins |
| [`system_defaults` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/system_defaults){ .role-link aria-label="system_defaults role on GitHub" } | Apply macOS preferences, Dock items, and keyboard settings |
| [`handoff` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/handoff){ .role-link aria-label="handoff role on GitHub" } | Prepare the persistent runtime used by `mise run reconcile` |

</div>

On macOS, the Homebrew role downloads the current signed `Homebrew.pkg` and
installs it through Ansible's become mechanism. On Ubuntu, Ansible first creates
the user-owned Linuxbrew prefix, then runs Homebrew's current shell installer
without sudo. Neither installer needs access to the user's password.

## Routine work with mise

The initial setup installs `mise` and the tools pinned by this repository.
After that bootstrap, run routine workflows from the repository checkout with
`mise run`. List the available tasks and their descriptions at any time:

```bash
mise tasks
```

<div class="setup-reference" markdown>

| Command | Purpose |
| --- | --- |
| `mise run reconcile` | Install the required Ansible collections and reconcile the machine. |
| `mise run reconcile:check` | Preview the reconciliation using Ansible check mode. |
| `mise run ansible:validate-runtime` | Report and validate the checkout, uv, Python, Ansible, locked dependencies, and collections. |
| `mise run status` | Show differences between the chezmoi source and files in the home directory. |
| `mise run import` | Import all modified, non-template managed files into `config/`. |
| `mise run import ~/.config/nvim` | Import one managed file or directory. |
| `mise run docs` | Serve the documentation at <http://localhost:8000> and rebuild it on changes. |
| `mise run docs:build` | Build the documentation with strict validation. |

</div>

!!! important "Bootstrap before using tasks"

    `mise` is the task runner, but it is also installed by Ansible. On a new
    machine, run `./scripts/setup.sh` first. The mise tasks are the
    post-bootstrap interface, not a replacement for initial setup.

Task execution installs any missing tools declared in `mise.toml`
automatically. Before each reconciliation, the runtime validator prints the
persistent checkout commit and every version selected by the shared lock and
collection requirements.

### Import local dotfile changes

When a managed file was edited directly in the home directory, inspect the
differences before copying them back into the repository:

```bash
mise run status
mise run import ~/.config/nvim
git diff -- config
```

Omit the path to import every modified managed file. The task uses
`chezmoi re-add`, which does not overwrite template source files.
For a rendered file backed by `config/**/*.tmpl`, reconcile the local change
with its template explicitly. Always review the resulting Git diff before
committing.

### Preview the documentation

Start the local Zensical server with:

```bash
mise run docs
```

Open <http://localhost:8000>. The preview rebuilds when documentation,
configuration, templates, CSS, or JavaScript change. Before committing a docs
change, run the strict build:

```bash
mise run docs:build
```

## Reapply after an update

After the initial setup has installed `mise`, pull the latest changes, review
them, and rerun the Ansible stage:

```bash
git pull --ff-only
git diff HEAD@{1} -- scripts/common/ansible config
mise run reconcile
```

The roles are designed to be rerun, and a repeated run should leave converged
state unchanged. Setup may still refresh Homebrew metadata and update managed
formulae or versioned casks, so review changes before rerunning after a long
gap.

There is no repository-wide upgrade command. Use `brew upgrade` for an
intentional full Homebrew upgrade, let Renovate propose changes to versions
declared in the repository, and use Lazy, Fisher, or TPM for intentional plugin
updates. Review and commit any resulting lockfile, manifest, or Ansible pin
changes. The checked-out chezmoi source remains authoritative and is
force-applied during setup.

## Try the Linux path in Docker

Run the published image:

```bash
docker run --rm -it shmileee/dotfiles
```

Test the current checkout in Docker:

```bash
mise run test:docker
```

`mise run test:docker` builds the integration fixture from the current checkout
and verifies that setup completes on Ubuntu.

Build an image from the current checkout:

```bash
docker build -t dotfiles --progress plain .
```

The image starts fish as the non-root `linuxbrew` user.

## Validate changes locally

Run the repository's static checks and Ansible syntax validation:

```bash
mise install
mise run ansible:validate-runtime
mise run test:docker
mise run test:bats
mise run bootstrap:lint
mise exec -- prek run --all-files
mise exec -- env \
  ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
  ANSIBLE_COLLECTIONS_PATH=bootstrap/.ansible/collections \
  uv run --project bootstrap --locked --managed-python \
  ansible-playbook --inventory '127.0.0.1,' \
  --syntax-check scripts/common/ansible/main.yaml
```

If the prerequisites are installed, preview the playbook too:

```bash
mise run reconcile:check
```

## Why Ansible and chezmoi?

Ansible owns machine state: packages, applications, services, shell setup, and
operating-system preferences. Its roles make the order and platform conditions
explicit, and repeated runs provide a practical convergence check.

chezmoi owns files in the home directory. It renders templates using facts such
as the operating system and architecture, which keeps one source tree useful
across macOS and the Ubuntu integration environment. Keeping these
responsibilities separate makes it clear whether a change belongs to the
machine or to the user's configuration.

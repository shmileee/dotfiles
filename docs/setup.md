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

- install apt packages, Homebrew packages, and macOS applications;
- change your login shell to fish;
- initialize chezmoi and force-apply files from this repository;
- install tmux and Neovim plugins;
- install Rancher Desktop on macOS; and
- change macOS defaults, Dock contents, and keyboard shortcuts.

Back up your existing configuration before continuing. At minimum, inspect
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
and the files under
[`config/`](https://github.com/shmileee/dotfiles/tree/master/config).

### Platform requirements

=== "Apple Silicon macOS"

    Install available system updates and the Xcode Command Line Tools on a
    fresh machine:

    ```bash
    sudo softwareupdate -i -a
    xcode-select --install
    ```

=== "Ubuntu 24.04 ARM64"

    Use an account with `sudo` access. The bootstrap installs the apt
    prerequisites, adds the Ansible PPA, and then installs Homebrew.

Apple Silicon macOS is the supported workstation target. Ubuntu 24.04 ARM64 is
the continuously tested container and integration target. The setup may work
on other Debian-family systems, but those systems are best effort. Other
operating systems are rejected.

## Recommended: review, then run

Clone the repository so you can inspect exactly what the setup will run. Pay
particular attention to
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
and the
[`main.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml)
playbook:

```bash
git clone https://github.com/shmileee/dotfiles.git
cd dotfiles

less scripts/common/ansible/config.yaml
less scripts/common/ansible/main.yaml
```

When you are comfortable with the configuration, run the complete setup:

```bash
./scripts/setup.sh --all
```

The script uses the current checkout, so local changes to package lists,
Ansible roles, or managed dotfiles are included.

## Fast path: bootstrap a new machine

```bash
curl -fsSL oponomarov.com/d | sh -s -- --all
```

The short URL redirects to
[`scripts/setup.sh`](https://github.com/shmileee/dotfiles/blob/master/scripts/setup.sh)
on the `master` branch. The
script downloads that branch into a unique temporary directory, runs the full
setup, and removes the temporary checkout when it exits.

??? "Download the script before running it"

    If you want the convenience of the bootstrap without piping directly into
    a shell:

    ```bash
    curl -fsSL https://raw.githubusercontent.com/shmileee/dotfiles/master/scripts/setup.sh > setup.sh
    less setup.sh
    chmod +x setup.sh
    ./setup.sh --all
    ```

## What `--all` does

<ol class="install-flow">
  <li>
    <span>01</span>
    <div>
      <strong>Validate the platform</strong>
      <p>Continue only on macOS or Linux, then locate the current checkout or download one.</p>
    </div>
  </li>
  <li>
    <span>02</span>
    <div>
      <strong>Prepare Ubuntu</strong>
      <p>On the tested Linux target, install the required apt packages and Ansible before the shared setup begins.</p>
    </div>
  </li>
  <li>
    <span>03</span>
    <div>
      <strong>Prepare Homebrew</strong>
      <p>Install Homebrew if necessary, add it to the current process, and disable analytics.</p>
    </div>
  </li>
  <li>
    <span>04</span>
    <div>
      <strong>Run Ansible</strong>
      <p>Install the required collections, prompt for a sudo password if needed, and run the local playbook.</p>
    </div>
  </li>
</ol>

## Run one stage

Stage flags must be run from a repository checkout.

<div class="setup-reference" markdown>

| Command | Purpose |
| --- | --- |
| `./scripts/setup.sh --deps` | Install apt prerequisites on Linux; tested on Ubuntu 24.04 ARM64. |
| `./scripts/setup.sh --brew` | Install Homebrew if it is missing. |
| `./scripts/setup.sh --ansible` | Install Ansible collections and run every role. |
| `./scripts/setup.sh --all` | Run the complete platform-specific sequence. |
| `./scripts/setup.sh` | Same as `--all`. |

</div>

If the prerequisites are already installed, use Ansible to preview supported
changes:

```bash
./scripts/common/ansible.sh --all --check
```

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
points chezmoi at the current repository checkout. The role force-applies that
checkout's [`config/`](https://github.com/shmileee/dotfiles/tree/master/config)
directory, so a fork or local changes can be tested without changing a separate
repository or branch setting.

### Ansible roles

<div class="setup-reference" markdown>

| Role | Responsibility |
| --- | --- |
| [`common` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/common){ .role-link aria-label="common role on GitHub" } | Install shared command-line tools and platform-specific packages and applications |
| [`fonts` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/fonts){ .role-link aria-label="fonts role on GitHub" } | Install developer fonts on macOS or the Ubuntu integration environment |
| [`dotfiles` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/dotfiles){ .role-link aria-label="dotfiles role on GitHub" } | Install chezmoi and apply the current checkout |
| [`fish` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/fish){ .role-link aria-label="fish role on GitHub" } | Install fish, make it the login shell, and synchronize Fisher plugins |
| [`mise` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/mise){ .role-link aria-label="mise role on GitHub" } | Install the tools declared in the mise configuration |
| [`neovim` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/neovim){ .role-link aria-label="neovim role on GitHub" } | Install LazyVim and its plugins in headless mode |
| [`docker` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/docker){ .role-link aria-label="docker role on GitHub" } | Install Rancher Desktop on macOS |
| [`tmux` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/tmux){ .role-link aria-label="tmux role on GitHub" } | Install tmux, TPM, and declared plugins |
| [`system_defaults` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/system_defaults){ .role-link aria-label="system_defaults role on GitHub" } | Apply macOS preferences, Dock items, and keyboard settings |

</div>

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
| `mise run status` | Show differences between the chezmoi source and files in the home directory. |
| `mise run import` | Import all modified, non-template managed files into `config/`. |
| `mise run import ~/.config/nvim` | Import one managed file or directory. |
| `mise run docs` | Serve the documentation at <http://localhost:8000> and rebuild it on changes. |
| `mise run docs:build` | Run the strict documentation build used by CI. |

</div>

!!! important "Bootstrap before using tasks"

    `mise` is the task runner, but it is also installed by Ansible. On a new
    machine, run `./scripts/setup.sh --all` first. The mise tasks are the
    post-bootstrap interface, not a replacement for initial setup.

Task execution installs any missing tools declared in `mise.toml`
automatically.

### Import local dotfile changes

When a managed file was edited directly in the home directory, inspect the
differences before copying them back into the repository:

```bash
mise run status
mise run import ~/.config/nvim
git diff -- config
```

Omit the path to import every modified managed file. The task uses
`chezmoi re-add`, which deliberately does not overwrite template source files.
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
change, run the same strict build as CI:

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

Or build the current checkout:

```bash
docker buildx build --platform linux/arm64 -t dotfiles --progress plain .
```

The image uses Ubuntu 24.04 ARM64 and runs the full Ansible installation as the
non-root `linuxbrew` user. Its smoke test verifies the installed tools and a
second, idempotent provisioning pass. The `docker` role is intentionally
skipped inside the container.

## Validate changes locally

Run the same static checks and Ansible syntax validation used by CI:

```bash
mise install
mise exec -- scripts/common/ansible.sh --install
mise exec -- prek run --all-files
mise exec -- env ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
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

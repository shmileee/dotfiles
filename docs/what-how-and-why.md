---
title: Setup
description: Review, install, customize, and reapply the workstation configuration.
---

# Set up a workstation

<p class="page-lead">Use the review-first path for an existing machine. The one-line installer is intended for a new machine or for a configuration you already trust.</p>

<nav class="setup-paths" aria-label="Choose an installation path">
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

=== "macOS"

    Install available system updates and the Xcode Command Line Tools on a
    fresh machine:

    ```bash
    sudo softwareupdate -i -a
    xcode-select --install
    ```

=== "Debian-based Linux"

    Use an account with `sudo` access. The bootstrap installs the apt
    prerequisites, adds the Ansible PPA, and then installs Homebrew.

The documented Linux path targets Debian-based distributions. Other Linux
distributions are not supported. Systems other than macOS and Linux are
rejected.

## Recommended: review, then run

Clone the repository so you can inspect exactly what the setup will run:

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

The short URL redirects to `scripts/setup.sh` on the `master` branch. The
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
      <strong>Prepare Linux</strong>
      <p>On Linux, install the required apt packages and Ansible before the shared setup begins.</p>
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
| `./scripts/setup.sh --deps` | Install the Linux apt prerequisites. Linux only. |
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
| Packages and applications | `scripts/common/ansible/config.yaml` | Homebrew packages, casks, Dock items, keyboard shortcuts |
| System behavior | `scripts/common/ansible/roles/` | Installation logic and macOS defaults |
| Home-directory files | `config/` | fish, Git, tmux, Neovim, Alacritty, OpenCode |
| Tool versions | `config/private_dot_config/mise/config.toml` | Language runtimes and developer tools |

</div>

The `dotfiles` section in `config.yaml` controls which repository and branch
chezmoi initializes. The playbook then applies the current checkout's `config/`
directory, which makes a fork straightforward to test before publishing it.

### Ansible roles

<div class="setup-reference" markdown>

| Role | Responsibility |
| --- | --- |
| [`common` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/common){ .role-link aria-label="common role on GitHub" } | Install shared command-line tools and platform-specific packages and applications |
| [`fonts` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/fonts){ .role-link aria-label="fonts role on GitHub" } | Install developer fonts on macOS or Debian-based Linux |
| [`dotfiles` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/dotfiles){ .role-link aria-label="dotfiles role on GitHub" } | Install chezmoi and apply the current checkout |
| [`fish` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/fish){ .role-link aria-label="fish role on GitHub" } | Install fish, make it the login shell, and synchronize Fisher plugins |
| [`mise` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/mise){ .role-link aria-label="mise role on GitHub" } | Install the tools declared in the mise configuration |
| [`neovim` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/neovim){ .role-link aria-label="neovim role on GitHub" } | Install LazyVim and its plugins in headless mode |
| [`docker` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/docker){ .role-link aria-label="docker role on GitHub" } | Install Rancher Desktop on macOS |
| [`tmux` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/tmux){ .role-link aria-label="tmux role on GitHub" } | Install tmux, TPM, and declared plugins |
| [`system_defaults` <span aria-hidden="true">↗</span>](https://github.com/shmileee/dotfiles/tree/master/scripts/common/ansible/roles/system_defaults){ .role-link aria-label="system_defaults role on GitHub" } | Apply macOS preferences, Dock items, and keyboard settings |

</div>

## Reapply after an update

Pull the latest changes, review them, and rerun the Ansible stage:

```bash
git pull --ff-only
git diff HEAD@{1} -- scripts/common/ansible config
./scripts/setup.sh --ansible
```

The roles are designed to be rerun. A repeated run should leave converged state
unchanged, although tools managed by external installers may still report
their own updates.

## Try the Linux path in Docker

Run the published image:

```bash {.terminal-command}
docker run --rm -it shmileee/dotfiles
```

Or build the current checkout:

```bash {.terminal-command}
docker buildx build --platform linux/arm64 -t dotfiles --progress plain .
```

The image uses Ubuntu 24.04 and runs the full Ansible installation as the
non-root `linuxbrew` user. The `docker` role is intentionally skipped inside the
container.

## Why Ansible and chezmoi?

Ansible owns machine state: packages, applications, services, shell setup, and
operating-system preferences. Its roles make the order and platform conditions
explicit, and repeated runs provide a practical convergence check.

chezmoi owns files in the home directory. It renders templates using facts such
as the operating system and architecture, which keeps one source tree useful
across macOS, Linux, and the validation container. Keeping these responsibilities
separate makes it clear whether a change belongs to the machine or to the
user's configuration.

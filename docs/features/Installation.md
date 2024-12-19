# Installation

## Requirements

**Operating System**

This Ansible playbook currently supports macOS and Debian-based Linux
distributions. This limitation is intentional, ensuring a consistent
development environment across all machines.

### macOS

On a fresh installation of macOS, run the following commands:

```bash
sudo softwareupdate -i -a
xcode-select --install
```

Installing the Xcode Command Line Tools provides `git` and `make`, which are not included by default on macOS.

!!! warning
If Homebrew is already installed on your machine, ensure that you have full
ownership of all directories managed by `brew`. See [this GitHub
issue](https://github.com/homebrew/brew/issues/3665) for more details.

## Running `setup.sh`

Begin the installation process by running the
[`setup.sh`](https://github.com/shmileee/dotfiles/blob/master/scripts/setup.sh)
script. This script resolves the "chicken or the egg" problem by installing the
essential dependencies needed to run the Ansible playbook.

For a quick, one-step installation, you can run the script directly from a
remote source (recommended only if you’re comfortable with this approach):

```bash
curl -fsSL oponomarov.com/d | sh -s -- --all
```

Alternatively, you can download and review the script before executing it:

```bash
curl -fsSL https://raw.githubusercontent.com/shmileee/dotfiles/master/scripts/setup.sh > setup.sh
chmod +x setup.sh
./setup.sh --all
```

This script will:

- Download `github.com/shmileee/dotfiles` into `/tmp/.dotfiles` using any
  available tool (`git`, `curl`, or `wget`).
- If running on Linux, install the
  [`essentials`](https://github.com/shmileee/dotfiles/blob/master/scripts/linux/essentials.apt)
  system dependencies.
- Install Ansible. On Linux, this happens as part of the previous step, and on
  macOS, it is handled via Homebrew.
- Attempt to install Homebrew if it is not already present.
- Execute [`ansible.sh`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible.sh),
  which will:
  - Install the `community.general` Ansible collection.
  - Check for passwordless `sudo` availability. If not available, it will prompt for your password.
  - Run the
    [`main.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml)
    Ansible playbook.

## Ansible

The main configuration is handled by the [primary
playbook](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml),
which sets up the system and dotfiles.

You can customize the configuration in
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml),
where you’ll typically specify packages, versions (for tools managed by `mise`),
and other preferences.

The
[`dotfiles:`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L86-L88)
dictionary defines which repository and branch `chezmoi` will use to install
your dotfiles. If you’re reusing this playbook with your own dotfiles, make
sure to update these variables accordingly.

!!! warning
Some Ansible tasks assume certain dotfiles are present. For example, the
[`install tmux
plugins`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/roles/tmux/tasks/main.yaml)
task will fail if
[`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)
is missing or does not include `run '~/.tmux/plugins/tpm/tpm'`.

**Supported Ansible Roles:**

- `common`: Installs basic system dependencies on Debian-based distributions
  using `apt`, or Homebrew packages and casks on macOS.
- `fonts`: Installs fonts using Homebrew. (Implementation may change in the
  future.)
- `dotfiles`: Installs `chezmoi` via Homebrew, initializes the dotfiles
  repository, and updates files.
- `fish`: Installs `fish` shell using Homebrew, sets it as the default shell,
  and configures `fisher` and its plugins.
- `neovim`: Installs `neovim`. If `neovim.build_from_source` is `true`, then it is
  compiled from source. Otherwise, a nightly Debian package is downloaded, or on
  macOS, it is installed via a HEAD build from Homebrew.
- `mise`: Installs the `mise` version manager for granular control over specific
  tools. All managed tools and their versions are defined in `config.yaml`.
- `docker`: Installs Docker using Homebrew.
- `tmux`: Installs Tmux, TPM, and the plugins specified in `tmux.conf`.
- `system_defaults`: Applies opinionated macOS system settings and custom
  tweaks for applications like Rectangle or Alt-Tab. Use with caution, as these
  settings can be disruptive and may evolve over time.

# Installation

## Requirements

**Operating System**

This Ansible playbook only supports macOS and Debian-based Linux distributions.
This is by design to provide a consistent development experience across
machines.

### macOS

On a sparkling fresh installation of macOS:

```bash
sudo softwareupdate -i -a
xcode-select --install
```

The Xcode Command Line Tools includes `git` and `make` (not available on stock
macOS).

!!! warning
    If your machine has already homebrew preinstalled, - make sure you have the full
    ownership over directories managed by `brew`. See
    [this](https://github.com/homebrew/brew/issues/3665) issue for more information.

## Running `setup.sh`

Bootstrap the installation procedure by running
[`setup.sh`](https://github.com/shmileee/dotfiles/blob/master/scripts/setup.sh).
The script solves chicken or the egg problem by installing essential
dependencies to run Ansible playbook.

The script can be run directly with single `curl` command if you like living on
the edge:

```bash
curl -fsSL oponomarov.com/d | sh -s -- --all
```

Otherwise, just download the file somewhere, review its content and execute with
`--all` flag:

```bash
curl -fsSL https://raw.githubusercontent.com/shmileee/dotfiles/master/scripts/setup.sh > setup.sh
chmod +x setup.sh
./setup.sh --all
```

The script will:

- Download `github.com/shmileee/dotfiles` into `/tmp/.dotfiles` using any of
  the tools available (`git`, `curl`, `wget`)
- Install
  [`essential`](https://github.com/shmileee/dotfiles/blob/master/scripts/linux/essentials.apt)
  system dependencies if running on Linux
- Install Ansible (if running on Linux, this is part of the previous step,
  otherwise it is installed via `brew` in the step)
- Attempt to install homebrew (if it does not exist yet)
- Execute
  [`ansible.sh`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible.sh),
  which in turn will:

    - Install `community.general` Ansible collection
    - Check if passwordless `sudo` is available (if no, - the script will prompt you for
      password)
    - Execute
      [`main.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml)
      playbook

## Ansible


The
[following](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml)
playbook is the main entrypoint for configuring the actual system and dotfiles.
  

The
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
file allows you to personalize the setup to your needs. At most it contains a
list of packages and their versions (in case of tools managed by `asdf`) to
install.

The
[`dotfiles:`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L86-L88)
dictionary defines from which repository and branch chezmoi shall install the
dotfiles to the system. If you tend to reuse this playbook, make sure to adjust
the variable accordingly.

!!! warning
    Certain Ansible tasks expect specific dotfiles to be in place, e.g.
    [`install tmux
    plugins`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/roles/tmux/tasks/main.yaml#L22-L26)
    will fail if
    [`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf#L188)
    is missing or does not include `run '~/.tmux/plugins/tpm/tpm'` line.

Supported Ansible roles:

- `common` - Install basic system dependencies for Debian-based distribution
  using `apt` package manager if cannot be installed otherwise. Install common
  packages using homebrew. Install homebrew casks for macOS.
- `fonts` - Install fonts with homebrew. This might change in the future between
  platforms.
- `dotfiles` - Install chezmoi using homebrew. Initiate dotfiles repository and
  update files.
- `fish` - Install fish using homebrew. Set default user's shell to fish. Configure fisher and install plugins.
- `neovim` - Install neovim. If `neovim.build_from_source` is set to `true`, -
  neovim will be compiled. Otherwise, download nightly deb package from
  GitHub. On macOS neovim is installed using HEAD revision via brew.
- `lunarvim` - Install LunarVim and reapply chezmoi to populate `config.lua`
- `asdf` - Install asdf version manager for typical packages that need more
  granular control over. All tools and their respective versions are defined in
  `config.yaml`.
- `docker` - Install docker using brew.
- `tmux` - Install tmux, tpm and plugins defined in `tmux.conf`
- `system_defaults` - Install sane macOS system settings. It will also configure
  custom tweaks for applications like rectangle or alt-tab. Use this with
  caution as the settings are very opinionated and might break your existing
  setup. This role is also the subject for future changes - more things like
  custom keybinding will be introduced shortly.

## Installation Flow

```
   ┌────────────────────────────────────────────┐
┌──┤curl -fsSL oponomarov.com/d | sh -s -- --all│
│  └────────────────────────────────────────────┘
│
│
│     ┌─────────────────────────────────────┐
├───► │git clone shmileee/dotfiles.git /tmp │
│     └─────────────────────────────────────┘
│
│     ┌─────────────────────────┐     ┌──────────────────────────┐
├───► │./install_dependencies.sh├────►│ apt install <essentials> │
│     └─────────────────────────┘     └──────────────────────────┘
│
│     ┌──────────────────┐
├───► │./install_brew.sh │
│     └──────────────────┘
│
│     ┌────────────┐
└───► │./ansible.sh│
      └─────┬──────┘
            │
   ┌────────┘
   │
   │  ┌─────────────────────────┐
   ├─►│install community.general│
   │  └─────────────────────────┘
   │
   │  ┌──────────────────────────┐
   │  │ prompt for password if   │
   ├─►│ sudo is not passwordless │
   │  └──────────────────────────┘
   │
   │
   │  ┌───────────────────────────────┐
   └─►│ansible-playbook ... main.yaml │
      └───────────────┬───────────────┘
                      │
     ┌────────────────┘
     │                 ┌────────────────────────┐
     │  ┌──────┐       │ brew install <packages>│
     ├─►│common├──────►│ brew install <casks>   │
     │  └──────┘       └────────────────────────┘
     │
     │  ┌───────┐
     ├─►│ fonts │
     │  └───────┘
     │                 ┌───────────────┐
     │  ┌──────────┐   │ chezmoi init  │
     ├─►│ dotfiles ├──►│ chezmoi update│
     │  └──────────┘   └───────────────┘
     │
     │
     │
     │  ┌────┐         ┌────────────────────┐
     ├─►│fish├───────┐ │change default shell│
     │  └────┘       └►│install fisher      │
     │                 │install fish plugins│
     │                 └────────────────────┘
     │
     │
     │                 ┌──────────────────────┐
     │  ┌──────┐       │ either:              │
     ├─►│neovim├──────►│  - build from source │
     │  └──────┘       │  - install binary    │
     │                 └──────────────────────┘
     │
     │
     │                 ┌───────────────────────────┐
     │  ┌────────┐     │ download                  │
     ├─►│lunarvim├────►│ install                   │
     │  └────────┘     │ update config with chezmoi│
     │                 └───────────────────────────┘
     │
     │
     │                 ┌────────────────────┐
     │  ┌────┐         │ install plugins    │
     ├─►│asdf├────────►│ install tools      │
     │  └────┘         │ set global versions│
     │                 └────────────────────┘
     │
     │  ┌────┐         ┌────────────────────┐
     ├─►│ go ├────────►│ install go packages│
     │  └────┘         └────────────────────┘
     │
     │  ┌────────┐
     ├─►│ docker │
     │  └────────┘     ┌──────────────────────┐
     │                 │install plugin manager│
     │  ┌──────┐    ┌─►│install plugins       │
     ├─►│ tmux ├────┘  └──────────────────────┘
     │  └──────┘
     │
     │  ┌─────────────────┐
     └─►│ system_defaults │
        └───────┬─────────┘
                │          ┌───────────────────────────────┐
                ├─────────►│ defaults write <apps settings>│
                │          └───────────────────────────────┘
                │
                │          ┌────────────────────┐
                ├─────────►│reorder apps in dock│
                │          └────────────────────┘
                │
                │          ┌──────────────────────┐
                ├─────────►│set custom keybindings│
                │          └──────────────────────┘
                │
                │          ┌───────────────────────┐
                └─────────►│defaults write <system>│
                           └───────────────────────┘
```

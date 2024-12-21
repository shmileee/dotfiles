### What?

This repository includes:

1. **The `setup.sh` script**: A single entry point for setting up and
   configuring a new macOS or Debian-based Linux system.
2. **Personalized `ansible` roles and playbooks**: Designed to install and
   configure various development tools efficiently. These roles emphasize
   idempotency and are compatible with both macOS and Debian-based distributions,
   using Homebrew as the primary package manager.
3. **Tools and dependency management**: The `setup.sh` script ensures that all
   necessary tools and prerequisites are installed to enable seamless execution
   of the `ansible-playbook` command.
4. **Personalized dotfiles**: Managed with the `chezmoi` dotfiles manager,
   providing a consistent and customized environment across systems.

### How?

Below is a non-exhaustive list of the tools used to achieve the desired setup:

- **Dotfiles management**: [`chezmoi`](https://www.chezmoi.io).
- **Editor**
    - [`neovim`](https://neovim.io) as my primary command-line editor.
    - [`lazyvim`](https://www.lazyvim.org/) as the main `neovim` distribution.
- **Shell**
    - [`fish`](https://fishshell.com) as my primary shell ([`~/.config/fish`](https://github.com/shmileee/dotfiles/tree/master/config/private_dot_config/private_fish)).
    - [`fisher`](https://github.com/jorgebucaran/fisher) for plugin management
      ([`fish_plugins`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_fish/private_fish_plugins)).
- **Terminal**:
    - [`alacritty`](https://alacritty.org) as my terminal emulator
      ([`alacritty.toml`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_alacritty/alacritty.toml.tmpl)).
    - [`tmux`](https://github.com/tmux/tmux) as a terminal multiplexer ([`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)).
        - [`tpm`](https://github.com/tmux-plugins/tpm) for managing `tmux` plugins.
- **Package management**:
    - [`homebrew`](https://brew.sh) as my primary package manager ([casks + formulas](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L10)).
    - [`mise`](https://blog.oponomarov.com/posts/mise-faster-smarter-tool-versioning) as a version manager for various system tools.

All of these tools are installed with `ansible`. The main configuration is
handled by the [primary
playbook](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/main.yaml),
which sets up the system and dotfiles. You can customize the configuration in
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml),
where you’ll typically specify packages and other preferences. The
[`dotfiles{}`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L86-L88)
dictionary defines which repository and branch `chezmoi` will use to install
your dotfiles from.
[`mise/config.toml`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/mise/config.toml)
defines what tools and runtimes are managed with `mise`.

!!! warning

    If you’re reusing this playbook with your own dotfiles, make
    sure to update these variables accordingly.

??? "Supported `ansible` roles"

    - `common`: Installs basic system dependencies on Debian-based distributions
      using `apt`, or `brew` packages and casks on macOS.
    - `fonts`: Installs fonts using `brew`.
    - `dotfiles`: Installs `chezmoi` via `brew`, initializes the dotfiles
      repository, and updates files.
    - `fish`: Installs `fish` shell using `brew`, sets it as the default shell,
      and configures `fisher` and its plugins.
    - `neovim`: Installs `neovim`. If `neovim.build_from_source` is `true`, then it is
      compiled from source. Otherwise, a nightly Debian package is downloaded, or on
      macOS, it is installed via a `brew`.
    - `mise`: Installs the `mise` version manager for granular control over specific
      tools. All managed tools and their versions are defined in `config.yaml`.
    - `docker`: Installs Docker using `brew`.
    - `tmux`: Installs `tmux`, `tpm`, and the plugins specified in `tmux.conf`.
    - `system_defaults`: Applies opinionated macOS system settings and custom
      tweaks for applications like Rectangle or Alt-Tab. Use with caution, as these
      settings can be disruptive and may evolve over time.

---

### Why?

My goal was to provide a fully automated development environment that’s both
easy to set up and maintain.

#### Why `ansible`?

In my experience, `ansible` is one of the easiest automation tools to learn.
Although it has its share of nuances, its YAML-based configuration is generally
straightforward to understand, even for users with limited knowledge of
`ansible`. It’s almost like reading plain English most of the time.

Additionally, `ansible` is like a Swiss Army knife of orchestration tools. It
can be adapted to a wide range of tasks, some of which might not be supported
by other popular solutions like `NixOS Home Manager`. One of its greatest
strengths is that tasks, when properly described, adhere to the principle of
[idempotency](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-Idempotency).
This means you can rerun a playbook repeatedly without worrying about
unintended removal or duplication of your files.

In a world full of automation solutions, I simply happen to enjoy using
`ansible` the most.

---

#### Why `chezmoi`?

`chezmoi` is a powerful tool for managing dotfiles. It’s currently one of the
most popular solutions. Before `chezmoi`, I used `gnu stow`, which worked fine
but lacked several features that `chezmoi` conveniently provides.

Key benefits of `chezmoi` include:

- **Flexible**: Dotfiles can be templates using `text/template` syntax. While
  `ansible` has Jinja templates, `chezmoi` offers built-in variables for platform
  detection, architecture, hostname, environment variables, and more. Testing
  these templates in `chezmoi` is much simpler — just run `chezmoi execute-template
< file.tmpl`.
- **Portable**: `chezmoi` configurations rely solely on visible, regular files
  and directories, ensuring portability across different version control systems
  and operating systems.
- **Transparent**: Verbose and dry-run modes let you preview changes before
  they’re applied, giving you complete control over what happens in your home
  directory.
- **Practical**: `chezmoi` manages hidden files, directories, private files,
  and executables — essentially all the typical elements of a dotfiles
  repository.
- **Fast and easy to use**: `chezmoi` runs in fractions of a second, and it
  provides commands that simplify most common operations.

By using `chezmoi`, I can adhere to the single-responsibility principle:
managing dotfiles independently from other system configuration tasks.

---

#### Why `lazyvim`?

I used `vim` for years until my configuration ballooned to over 500 lines,
making it a challenge to maintain. My switch to `neovim` was inspired by talks
from [ThePrimagen](https://github.com/ThePrimeagen) and [TJ
DeVries](https://github.com/tjdevries), which also made me realize I didn’t
fully grasp the Lua-based configuration system that `neovim` uses.

It turned out that most of the common keymaps, plugins, and sensible defaults I
was after were already configured by many in the `neovim` community. This is
how I discovered `lazyvim`: it provides a community-driven framework for
`neovim`, bundling common plugins and sensible defaults. This allowed me to
avoid starting from scratch and reinventing the wheel. I only needed to add a
few extra plugins, tweak some keybindings, and configure fewer than ten
settings to feel completely at home.

---

#### Why `fish`?

The `fish` ecosystem excels as an interactive shell. While I still write my
scripts in `bash` for portability, the out-of-the-box features in `fish`, such
as autosuggestions and robust tab completions, are too convenient to pass up.

---

#### Why `mise`?

I've described this in a blog post
[here](https://blog.oponomarov.com/posts/mise-faster-smarter-tool-versioning).

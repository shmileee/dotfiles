**Tools**

---

Below is a non-exhaustive list of the tools and configurations used:

- **Dotfiles Management**

  - [Chezmoi](https://www.chezmoi.io) for managing dotfiles.

- **Editor**

  - [Neovim](https://neovim.io) as my primary command-line editor.
    - [LazyVim](https://www.lazyvim.org/) as the main Neovim distribution.

- **Shell**

  - [Fish](https://fishshell.com) as my primary shell ([`~/.config/fish`](https://github.com/shmileee/dotfiles/tree/master/config/private_dot_config/private_fish)).
    - [Fisher](https://github.com/jorgebucaran/fisher) for plugin management
      ([`fish_plugins`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_fish/private_fish_plugins)).
  - [Tmux](https://github.com/tmux/tmux) as a terminal multiplexer ([`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)).
    - [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) for managing Tmux plugins.

- **Package Management**

  - [Homebrew](https://brew.sh) as my primary package manager ([casks + formulas](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L10)).
  - [Mise](https://blog.oponomarov.com/posts/mise-faster-smarter-tool-versioning) as a version manager for various system tools.

- **Applications**
  - [Alacritty](https://alacritty.org) as my terminal emulator
    ([`alacritty.toml`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_alacritty/alacritty.toml.tmpl)).
  - [Brave](https://brave.com) as my primary web browser.
  - [Rectangle](https://rectangleapp.com) for window management.
  - [Fzf](https://github.com/junegunn/fzf) as a command-line fuzzy finder.

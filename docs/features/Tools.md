# Tools
---

Here's a non-exhaustive list of everything I used in my personal dotfiles.

- [Chezmoi](https://www.chezmoi.io) as dotfiles manager.

**Editor**

- [Neovim](https://neovim.io) as primary editor on the command line.
    - [LunarVim](https://www.lunarvim.org) as primary neovim distribution
    ([`config.lua`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_lvim/config.lua)).

**Shell**

- [Fish Shell](https://fishshell.com) as primary shell ([`~/.config/fish`](https://github.com/shmileee/dotfiles/tree/master/config/private_dot_config/private_fish)).
    - [Fisher](https://github.com/jorgebucaran/fisher) as plugin manager
      ([`fish_plugins`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_fish/private_fish_plugins)).

- [Tmux](https://github.com/tmux/tmux) as terminal multiplexer ([`tmux.conf`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_tmux/tmux.conf)).
    - [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) as plugin manager.

**Packages**

- [homebrew](https://brew.sh/) as primary package manager ([casks +
  formulas](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L10)).
- [asdf](https://asdf-vm.com) as version manager for various system tools
  ([packages](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml#L108)).

**Apps**

- [Alacritty](https://alacritty.org) as terminal emulator ([`alacritty.yml`](https://github.com/shmileee/dotfiles/blob/master/config/private_dot_config/private_alacritty/alacritty.yml.tmpl)).
- [Brave](https://brave.com) as primary web browser.
- [Rectangle](https://rectangleapp.com) as windows manager.
- [Fzf](https://github.com/junegunn/fzf) as command-line fuzzy finder.

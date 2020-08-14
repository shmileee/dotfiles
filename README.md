# dotfiles

Here's a bunch of settings for the various tools I use. 

## Quickly Get Set Up with These Dotfiles

A few copy / paste'able commands that you can use to install part of these
dotfiles on Ubuntu 20.04 LTS inside WSL1.

```sh
sudo apt-get update && sudo apt-get install -y \
  gnupg1 \
  vim-gtk \
  tmux \
  git \
  gpg \
  curl \
  rsync \
  unzip \
  htop \
  shellcheck \
  ripgrep \
  pass \
  python3-pip \
  jq \
  golang \
  golang-go \
  dos2unix

# Install oh-my-bash framework
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# Clone down this dotfiles repo to your home directory. Feel free to place
# this anywhere you want, but remember where you've cloned things to.
git clone https://github.com/shmileee/dotfiles ~/dotfiles

mkdir -p ~/.local/bin && mkdir -p ~/.vim/spell \
  && ln -s ~/dotfiles/.aliases ~/.oh-my-bash/aliases/custom.aliases.sh \
  && ln -s ~/dotfiles/.docker.aliases ~/.oh-my-bash/aliases/docker.aliases.sh \
  && ln -s ~/dotfiles/.bashrc ~/.bashrc \
  && ln -s ~/dotfiles/.gitconfig ~/.gitconfig \
  && ln -s ~/dotfiles/.tmux.conf ~/.tmux.conf \
  && ln -s ~/dotfiles/.vimrc ~/.vimrc
  && ln -s ~/dotfiles/.gitconfig.user ~/.gitconfig.user

# Install Plug (Vim plugin manager).
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install FZF (fuzzy finder on the terminal and used by a Vim plugin).
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install

# Install Ansible.
pip3 install --user ansible

# Install Terraform.
curl "https://releases.hashicorp.com/terraform/0.12.26/terraform_0.12.26_linux_amd64.zip" -o "terraform.zip" \
  && unzip terraform.zip && chmod +x terraform \
  && mv terraform ~/.local/bin && rm terraform.zip
```

Optionally confirm that a few things work after closing and re-opening your
terminal:

```sh
# Sanity check to see if you can run some of the tools we installed.
ansible --version
terraform --version

# Check to make sure git is configured with your name, email and custom settings.
git config --list

# Open Vim and install the configured plugins. You would type in the
# :PlugInstall command from within Vim and then hit enter to issue the command.
vim .
:PlugInstall
```

## Windows specific

In addition to the Linux side of things, there's a few config files that I have
in various directories of this dotfiles repo. These have long Windows paths.

It would be expected that you copy those over to your system while replacing "oleksandrp"
with your Windows user name if you want to use those things, such as my
Microsoft Terminal `settings.json` file and others. Some of the paths may
also contain unique IDs too, so adjust them as needed on your end.

## VSCode

I also use VSCode for various tasks. `Settings Sync` plugin is in charge of
keeping my VSCode specific settings in sync across all computers. Gist file 
is [here](https://gist.github.com/shmileee/f6415a0e35ea0350a2ecce4cb3c004a5).

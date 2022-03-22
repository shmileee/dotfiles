# Dotfiles

Welcome! This is the documentation for my dotfiles repository.

### Getting Started

The preferred method of installation is to do a fresh install of macOS or Debian
based Linux, then run the automated setup script:

```bash
curl -fsSL oponomarov.com/dot | sh -s -- --all
```

To learn how to use my setup, what features are available, and how to tweak the
configurations to suit your tastes, please read the [Usage
Guide](features/UsageGuide) section.

### Highlights

- Minimal efforts to install everything
- Mostly based around Ansible, Homebrew and Shell scripts
- Fast and colored prompt
- Single responsibility principle - one tool to manage one thing
- Sane macOS defaults
- Well-organized and easy to customize
- The installation and setup is
  [tested](https://github.com/shmileee/dotfiles/actions) weekly on real Ubuntu +
  macOS machines as well as Ubuntu 20.04 Docker container using [a GitHub
  Actions](./.github/workflows)
- Supports both Apple Silicon (M1) and Intel chips
- Battle-tested

!!! warning
    The `dotfiles` repository is still in "early" development stage. While
    providing _mostly_ a usable system out of the box, some functionality might
    still be missing.

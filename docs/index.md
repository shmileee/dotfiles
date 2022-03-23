# Dotfiles

Welcome! This is the documentation for my dotfiles repository.

### Getting Started

The preferred method of installation is to do a fresh install of macOS or Debian
based Linux, then run the automated setup script:

```bash
curl -fsSL oponomarov.com/d | sh -s -- --all
```


!!! info
    You can see the repository in action by running `docker run -it
    shmileee/dotfiles` and spawning a prebuilt docker container with interactive
    tty. The size is almost 4GB.

To learn about the rationale behind my setup, how to use it, what features are
available and how to tweak the configurations to suit your tastes, please read
the [Usage Guide](features/1-UsageGuide) section.

### Highlights

- Sane macOS defaults
- Fast and colored prompt
- Well-organized and easy to customize
- Minimal efforts to install everything
- Mostly based around Ansible, Homebrew and Chezmoi
- Single responsibility principle - one tool manages one thing
- The installation and setup is
  [tested](https://github.com/shmileee/dotfiles/actions) weekly on:
    - real Ubuntu + macOS machines
    - Ubuntu 20.04 Docker container
- Supports both Apple Silicon (M1) and Intel chips

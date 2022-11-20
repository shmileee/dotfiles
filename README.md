# Dotfiles

Fully automated development environment. Read the full documentation
[here](https://oponomarov.com).

[![macos](https://github.com/shmileee/dotfiles/actions/workflows/macos.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/macos.yaml)
[![docker](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml)

## Installation

Install everything with single `curl` command:

```bash
curl -fsSL oponomarov.com/d | sh -s -- --all
```

## Running Inside Docker

Run `docker run -it shmileee/dotfiles` to spawn a docker container which is
automatically [built and
pushed](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml) with
GitHub Actions or build your own:

```bash
docker buildx build --platform linux/amd64 -t dotfiles --progress plain .
```

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

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).

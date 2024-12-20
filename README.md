# Dotfiles

Fully automated development environment. Read the full documentation
[here](https://dotfiles.oponomarov.com).

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

```mermaid
flowchart TD
    A["curl -fsSL oponomarov.com/d | sh -s -- --all"]
    A --> B["git clone shmileee/dotfiles.git /tmp"]

    B --> C["./install_dependencies.sh (apt install < essentials >)"]
    B --> D["./install_brew.sh"]

    B --> E["./ansible.sh"]
    E --> F["install community.general, prompt if needed"]
    E --> G["ansible-playbook ... main.yaml"]
```

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).

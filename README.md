# Dotfiles

Fully automated development environment. Read the full documentation
[here](https://oponomarov.com).


[![macos](https://github.com/shmileee/dotfiles/actions/workflows/macos.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/macos.yaml)
[![docker](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml)

## Installation

On a sparkling fresh installation of macOS / Debian based distribution:

```bash
sudo softwareupdate -i -a
xcode-select --install
```

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

## Additional Resources

- [Awesome Dotfiles](https://github.com/webpro/awesome-dotfiles)
- [Homebrew](https://brew.sh)

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).

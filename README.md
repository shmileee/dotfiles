# Dotfiles

Fully automated development environment. Read the full documentation
[here](https://dotfiles.oponomarov.com).

Supported targets are Apple Silicon macOS workstations and the Ubuntu 24.04
ARM64 integration image. A normal setup reconciles declared state; upgrades are
allowed to occur through Homebrew and each tool's native update workflow.

[![macos](https://github.com/shmileee/dotfiles/actions/workflows/macos.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/macos.yaml)
[![docker](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/docker.yaml)
[![validate](https://github.com/shmileee/dotfiles/actions/workflows/validate.yaml/badge.svg)](https://github.com/shmileee/dotfiles/actions/workflows/validate.yaml)

## Documentation development

The documentation site uses Zensical. With `uv` installed, preview the pinned
documentation environment locally with:

```sh
uv run --python 3.14 --with-requirements requirements-docs.txt \
  zensical serve
```

Open <http://localhost:8000>. The preview rebuilds when documentation,
configuration, template, CSS, or JavaScript files change. Run the same strict
build as CI with:

```sh
uv run --python 3.14 --with-requirements requirements-docs.txt \
  zensical build --strict
```

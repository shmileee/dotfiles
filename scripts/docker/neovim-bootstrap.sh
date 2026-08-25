#!/usr/bin/env bash

set -euo pipefail

for phase in install install restore mason treesitter; do
	PATH="${HOME}/.local/share/nvim/mason/bin:${PATH}" NVIM_BOOTSTRAP_PHASE=$phase \
		mise exec -- nvim --headless "+luafile scripts/docker/neovim-bootstrap.lua"
done

#!/usr/bin/env bash

set -euo pipefail

assert_contains() {
	local output=$1
	local expected=$2

	if [[ "$output" != *"$expected"* ]]; then
		printf 'Expected output to contain %q, got %q\n' "$expected" "$output" >&2
		exit 1
	fi
}

assert_contains "$(uname -m)" "aarch64"
assert_contains "$(getent passwd "$(whoami)" | cut -d: -f7)" "fish"

fish --version
brew --version
chezmoi --version
tmux -V

assert_contains "$(nvim --version | sed -n '1p')" "NVIM v0.11.4"
nvim --headless "+lua assert(vim.g.snacks_animate == false)" +qa

assert_contains "$(mise exec -- go version)" "go1.23.4"
assert_contains "$(mise exec -- node --version)" "v22.13.0"
assert_contains "$(mise exec -- python --version)" "Python 3.14.3"
assert_contains "$(mise exec -- ruby --version)" "3.4.1"
assert_contains "$(mise exec -- terraform version)" "Terraform v1.14.8"
assert_contains "$(mise exec -- helm version --short)" "v3.16.3"
assert_contains "$(mise exec -- kubectl version --client)" "v1.32.0"

chezmoi_args=(
	--source /tmp/.dotfiles/config
	--working-tree /tmp/.dotfiles
	--exclude scripts
)
if ! chezmoi "${chezmoi_args[@]}" verify; then
	chezmoi "${chezmoi_args[@]}" diff
	exit 1
fi
assert_contains "$(fish -lc "echo \$EDITOR")" "nvim"
fish -lc 'type -q vim; and type -q nvim'

if command -v dockerd >/dev/null 2>&1; then
	echo "Docker Engine must not be installed in the E2E image" >&2
	exit 1
fi

echo "E2E assertions passed"

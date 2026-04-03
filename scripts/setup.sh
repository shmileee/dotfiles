#!/usr/bin/env bash

set -euoE pipefail

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

source="https://github.com/shmileee/dotfiles"
branch="${branch:-master}"
tarball="$source/tarball/$branch"
target="/tmp/.dotfiles"

display_help() {
	echo "Usage: ./setup.sh [arguments]..."
	echo
	echo "  --deps              install deps for linux"
	echo "  --brew              install brew for linux/macos"
	echo "  --ansible           execute ansible for linux/macos"
	echo "  --all               setup everything"
	echo "  -h, --help          display this help message"
	echo
}

exit_help() {
	display_help
	echo "Error: $1"
	exit 1
}

macos() { test "$(uname -s)" == "Darwin" && return 0; }
linux() { test "$(uname -s)" == "Linux" && return 0; }
is_executable() { type "$1" >/dev/null 2>&1; }

ensure_brew_in_path() {
	command -v brew &>/dev/null && return 0
	for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
		if [[ -x "${prefix}/bin/brew" ]]; then
			eval "$("${prefix}/bin/brew" shellenv)"
			return 0
		fi
	done
	return 1
}

download_repository() {
	mkdir -p "$target"
	if is_executable "git"; then
		git clone -b "$branch" "$source" "$target"
	elif is_executable "curl"; then
		curl -#L "$tarball" | tar -xzv -C "$target" --strip-components=1 --exclude='{.gitignore}'
	elif is_executable "wget"; then
		wget --no-check-certificate -O - "$tarball" | tar -xzv -C "$target" --strip-components=1 --exclude='{.gitignore}'
	else
		exit_help "No git, curl or wget available. Aborting."
	fi
}

setup_all() {
	test -d "$target" || download_repository
	if linux; then
		"${target}/scripts/linux/install_dependencies.sh"
	fi
	"${target}/scripts/common/install_brew.sh"
	ensure_brew_in_path
	if macos; then
		brew install ansible
	fi
	"${target}/scripts/common/ansible.sh" --all
}

# process arguments
while [[ $# -gt 0 ]]; do
	arg=$1
	case $arg in
	-h | --help)
		display_help
		exit 0
		;;
	--deps)
		"${cwd}/linux/install_dependencies.sh"
		;;
	--brew)
		"${cwd}/common/install_brew.sh"
		;;
	--ansible)
		"${cwd}/common/ansible.sh"
		;;
	--all)
		setup_all
		;;
	*)
		exit_help "Unknown argument: $arg"
		;;
	esac
	shift
done

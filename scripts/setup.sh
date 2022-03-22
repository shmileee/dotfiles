#!/usr/bin/env bash

set -euoE pipefail

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

source="https://github.com/shmileee/dotfiles"
branch="${branch:-master}"
tarball="$source/tarball/$branch"
target="/tmp/.dotfiles"
tar_cmd="tar -xzv -C $target --strip-components=1 --exclude='{.gitignore}'"


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

macos() { test "$(uname -s)" == "Darwin"  && return 0; }
linux() { test "$(uname -s)" == "Linux"  && return 0; }
is_executable() { type "$1" > /dev/null 2>&1; }

download_repository() {
  if is_executable "git"; then
    cmd="git clone -b $branch $source $target"
  elif is_executable "curl"; then
    cmd="curl -#L $tarball | $tar_cmd"
  elif is_executable "wget"; then
    cmd="wget --no-check-certificate -O - $tarball | $tar_cmd"
  fi

  if test -z "$cmd"; then
    exit_help "No git, curl or wget available. Aborting."
  else
    mkdir -p "$target"
    eval "$cmd"
  fi
}

setup_all() {
  test -d "$target" || download_repository
  if linux; then
    "${target}/scripts/linux/install_dependencies.sh"
  fi
  "${target}/scripts/common/install_brew.sh"
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

#!/usr/bin/env bash

set -euoE pipefail

source="https://github.com/shmileee/dotfiles"
branch="master"
tarball="$source/tarball/$branch"
repository=""
temporary_repository=""

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -x "${script_dir}/common/ansible.sh" ]]; then
    repository="$(cd "${script_dir}/.." && pwd)"
  fi
fi

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
is_executable() { type "$1" > /dev/null 2>&1; }

ensure_brew_in_path() {
  command -v brew &> /dev/null && return 0
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "${prefix}/bin/brew" ]]; then
      eval "$("${prefix}/bin/brew" shellenv)"
      return 0
    fi
  done
  return 1
}

download_repository() {
  temporary_repository="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXX")"
  repository="$temporary_repository"
  trap '[[ -z "$temporary_repository" ]] || rm -rf -- "$temporary_repository"' EXIT

  if is_executable "curl"; then
    curl -fsSL "$tarball" | tar -xz -C "$repository" --strip-components=1
  elif is_executable "wget"; then
    wget -qO- "$tarball" | tar -xz -C "$repository" --strip-components=1
  elif is_executable "git"; then
    git clone --depth 1 --branch "$branch" "$source" "$repository"
  else
    exit_help "No git, curl or wget available. Aborting."
  fi
}

setup_all() {
  if ! macos && ! linux; then
    exit_help "Only macOS and Linux are supported."
  fi

  [[ -n "$repository" ]] || download_repository
  if linux; then
    "${repository}/scripts/linux/install_dependencies.sh"
  fi
  "${repository}/scripts/common/install_brew.sh"
  ensure_brew_in_path
  if macos; then
    brew install ansible
  fi
  "${repository}/scripts/common/ansible.sh" --all
}

require_local_repository() {
  [[ -n "$repository" ]] || exit_help "This option must be run from a repository checkout."
}

[[ $# -gt 0 ]] || set -- --all

# process arguments
while [[ $# -gt 0 ]]; do
  arg=$1
  case $arg in
    -h | --help)
      display_help
      exit 0
      ;;
    --deps)
      require_local_repository
      linux || exit_help "--deps is only supported on Linux."
      "${repository}/scripts/linux/install_dependencies.sh"
      ;;
    --brew)
      require_local_repository
      "${repository}/scripts/common/install_brew.sh"
      ;;
    --ansible)
      require_local_repository
      "${repository}/scripts/common/ansible.sh" --all
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

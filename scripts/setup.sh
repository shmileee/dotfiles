#!/usr/bin/env bash

set -euoE pipefail

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

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
      if linux; then
        "${cwd}/linux/install_dependencies.sh"
      fi
      "${cwd}/common/install_brew.sh"
      if macos; then
        brew install ansible
      fi
      "${cwd}/common/ansible.sh" --all
      ;;
    *)
      exit_help "Unknown argument: $arg"
      ;;
  esac
  shift
done

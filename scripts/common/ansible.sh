#!/usr/bin/env bash

set -euoE pipefail

cwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
action=""
check_mode=false

login_shell_is_fish() {
  local current_shell desired_shell
  case "$(uname -s)" in
    Darwin)
      desired_shell="$(brew --prefix)/bin/fish"
      current_shell="$(
        /usr/bin/dscl -plist . -read "/Users/$(id -un)" UserShell |
          /usr/bin/plutil -extract dsAttrTypeStandard:UserShell.0 raw -o - -
      )"
      ;;
    Linux)
      desired_shell="/home/linuxbrew/.linuxbrew/bin/fish"
      current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
      ;;
    *)
      return 1
      ;;
  esac

  [[ "$current_shell" == "$desired_shell" ]]
}

needs_become_pass() {
  ! login_shell_is_fish && ! sudo -n true 2> /dev/null
}

install_collections() {
  local collections_dir="${HOME}/.ansible/collections"

  echo "⚪ [ansible] reconciling collections..."
  ANSIBLE_COLLECTIONS_PATH="$collections_dir" ansible-galaxy collection install \
    --force \
    --collections-path "$collections_dir" \
    --requirements-file "${cwd}/ansible/requirements.yml"
}

run_playbook() {
  echo "⚪ [ansible] running playbook..."
  local command=(
    ansible-playbook
    --inventory "127.0.0.1,"
    -e "ansible_user=$(whoami)"
    "${cwd}/ansible/main.yaml"
  )

  if [[ "$check_mode" == true ]]; then
    command+=("--check")
  fi
  if needs_become_pass; then
    command+=("--ask-become-pass")
  fi

  export ANSIBLE_CONFIG="${cwd}/ansible/ansible.cfg"

  if [[ -z "${CI:-}" && -z "${DOCKERIZED:-}" ]]; then
    command+=("-v")
  fi

  echo "${command[*]}"
  "${command[@]}"
  echo "✅ [ansible] configured!"
}

while [[ $# -gt 0 ]]; do
  arg=$1
  case $arg in
    --install)
      action="install"
      ;;
    --run)
      action="run"
      ;;
    --all)
      action="all"
      ;;
    --check)
      check_mode=true
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
  shift
done

case $action in
  install)
    install_collections
    ;;
  run)
    run_playbook
    ;;
  all)
    install_collections
    run_playbook
    ;;
  *)
    echo "Usage: $0 --install|--run|--all [--check]" >&2
    exit 1
    ;;
esac

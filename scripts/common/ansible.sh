#!/usr/bin/env bash

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

install_collections() {
  echo "⚪ [ansible] installing collections..."
  ansible-galaxy collection install community.general
}

run_playbook() {
  echo "⚪ [ansible] running playbook..."
  ansible-playbook -e "ansible_user=$(whoami)" "${cwd}/ansible/main.yml" -vvv
}

# process arguments
while [[ $# -gt 0 ]]; do
  arg=$1
  case $arg in
    --install)
      install_collections
      ;;
    --run)
      run_playbook
      ;;
    *)
      install_collections
      run_playbook
      ;;
  esac
  shift
done

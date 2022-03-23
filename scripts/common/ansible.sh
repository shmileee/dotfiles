#!/usr/bin/env bash

set -euoE pipefail

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

sudo_required() { sudo -n true 2>/dev/null || return 0; }

install_collections() {
  echo "⚪ [ansible] installing collections..."
  ansible-galaxy collection install community.general
}

run_playbook() {
  echo "⚪ [ansible] running playbook..."
  local playbook_opts=()

  if sudo_required; then
    playbook_opts+=("--ask-become-pass")
  fi

  export ANSIBLE_CONFIG="${cwd}/ansible/ansible.cfg"

  echo "ansible-playbook -e ansible_user=$(whoami) ${cwd}/ansible/main.yaml -v ${playbook_opts[*]}"
  ansible-playbook -e "ansible_user=$(whoami)" "${cwd}/ansible/main.yaml" -v "${playbook_opts[*]}"
  echo "✅ [ansible] configured!"
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
    --all)
      install_collections
      run_playbook
      ;;
  esac
  shift
done

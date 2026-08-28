#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -P "$(dirname "$0")" && pwd)
action=''
check_mode=0

usage() {
  cat << EOF
Usage: $(basename "$0") (--install | --run | --all) [--check]

  --install   install required Ansible collections
  --run       run the local playbook
  --all       install collections, then run the playbook
  --check     run the playbook in check mode
EOF
}

die() {
  printf '%s: %s\n' "$(basename "$0")" "$*" >&2
  exit 1
}

login_shell_is_fish() {
  ansible_user=$(id -un) || return 1
  brew_prefix=$(brew --prefix) || return 1
  desired_shell="${brew_prefix}/bin/fish"
  user_record=$(
    /usr/bin/dscl -plist . -read "/Users/${ansible_user}" UserShell
  ) || return 1
  current_shell=$(
    printf '%s\n' "${user_record}" \
      | /usr/bin/plutil \
        -extract dsAttrTypeStandard:UserShell.0 raw -o - -
  ) || return 1

  [ "$current_shell" = "$desired_shell" ]
}

needs_become_password() {
  user_id=$(id -u)
  [ "${user_id}" -eq 0 ] && return 1
  sudo -n true 2> /dev/null && return 1

  operating_system=$(uname -s)
  case ${operating_system} in
    Linux) return 0 ;;
    Darwin) ! login_shell_is_fish ;;
    *) return 1 ;;
  esac
}

install_collections() {
  collections_dir="${HOME}/.ansible/collections"

  printf '%s\n' '[ansible] Reconciling collections...'
  ANSIBLE_COLLECTIONS_PATH="$collections_dir" \
    ansible-galaxy collection install \
    --collections-path "$collections_dir" \
    --requirements-file "${script_dir}/ansible/requirements.yml"
}

run_playbook() {
  printf '%s\n' '[ansible] Running playbook...'
  playbook_user=$(id -un)

  set -- \
    ansible-playbook \
    --inventory '127.0.0.1,' \
    --extra-vars "ansible_user=${playbook_user}" \
    "${script_dir}/ansible/main.yaml"

  [ "$check_mode" -eq 0 ] || set -- "$@" --check
  needs_become_password && set -- "$@" --ask-become-pass

  if [ -z "${CI:-}" ] && [ -z "${DOCKERIZED:-}" ]; then
    set -- "$@" --verbose
  fi

  export ANSIBLE_CONFIG="${script_dir}/ansible/ansible.cfg"

  printf '[ansible] Executing:'
  printf ' %s' "$@"
  printf '\n'
  "$@"

  printf '%s\n' '[ansible] Configuration complete.'
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --install | --run | --all)
      [ -z "$action" ] || die 'specify exactly one action'
      action=${1#--}
      ;;
    --check)
      check_mode=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
  shift
done

case $action in
  install)
    [ "$check_mode" -eq 0 ] || die '--check requires --run or --all'
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
    usage >&2
    exit 2
    ;;
esac

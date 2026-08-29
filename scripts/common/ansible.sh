#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -P "$(dirname "$0")" && pwd)
project_dir="${script_dir}/ansible"
data_home=${XDG_DATA_HOME:-${HOME}/.local/share}
environment="${data_home}/dotfiles/ansible-runtime"
action=''
check_mode=0

PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
export PATH

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

find_uv() {
  bootstrap_uv="${data_home}/dotfiles/bootstrap/bin/uv"
  if [ -x "$bootstrap_uv" ]; then
    printf '%s\n' "$bootstrap_uv"
    return 0
  fi

  command -v uv > /dev/null 2>&1 \
    || die 'uv is required; run scripts/setup.sh first'
  command -v uv
}

uv_run() {
  UV_PROJECT_ENVIRONMENT="$environment" \
    "$uv" run --locked --project "$project_dir" "$@"
}

prepare_environment() {
  printf '%s\n' '[ansible] Reconciling the locked runtime...'
  UV_PROJECT_ENVIRONMENT="$environment" \
    "$uv" sync --locked --project "$project_dir"
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
  export ANSIBLE_COLLECTIONS_PATH="$collections_dir"

  printf '%s\n' '[ansible] Reconciling collections...'
  uv_run ansible-galaxy collection install \
    --collections-path "$collections_dir" \
    --requirements-file "${script_dir}/ansible/requirements.yml"
}

run_playbook() {
  printf '%s\n' '[ansible] Running playbook...'
  playbook_user=$(id -un)

  set -- \
    uv_run ansible-playbook \
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

[ -n "$action" ] || {
  usage >&2
  exit 2
}

uv=$(find_uv)
prepare_environment

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

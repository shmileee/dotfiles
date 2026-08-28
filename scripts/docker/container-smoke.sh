#!/bin/sh

set -eu

readonly repository='/tmp/.dotfiles'
log_file=''

cleanup() {
  [ -z "${log_file}" ] || rm -f -- "${log_file}"
}

phase() {
  printf 'SMOKE phase=%s\n' "$1"
}

cleanup_on_signal() {
  exit "$1"
}

trap cleanup 0
trap 'cleanup_on_signal 129' HUP
trap 'cleanup_on_signal 130' INT
trap 'cleanup_on_signal 143' TERM

cd "${repository}"

phase runtime-identity
runtime_user=$(id -un)
[ "${runtime_user}" = 'linuxbrew' ]
[ "${HOME}" = '/home/linuxbrew' ]

phase executables
for executable in brew chezmoi fish mise tmux; do
  command -v "${executable}" > /dev/null 2>&1
done

phase startup
fish_output=$(fish -c true)
[ -z "${fish_output}" ]
mise exec -- nvim --headless +qa

phase idempotence
log_file=$(mktemp "${TMPDIR:-/tmp}/ansible-idempotence.XXXXXX")

if scripts/common/ansible.sh --run > "${log_file}" 2>&1; then
  cat "${log_file}"
else
  status=$?
  cat "${log_file}" >&2
  exit "${status}"
fi

grep -Eq 'changed=0 +unreachable=0 +failed=0' "${log_file}"

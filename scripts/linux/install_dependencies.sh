#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -P "$(dirname "$0")" && pwd)

die() {
  printf '%s: %s\n' "$(basename "$0")" "$*" >&2
  exit 1
}

run_as_root() {
  user_id=$(id -u)

  if [ "${user_id}" -eq 0 ]; then
    "$@"
  else
    command -v sudo > /dev/null 2>&1 || die 'sudo is required'
    sudo "$@"
  fi
}

apt_get() {
  run_as_root apt-get \
    -o Acquire::Retries=3 \
    -o DPkg::Lock::Timeout=60 \
    "$@"
}

install_packages() {
  package_file=$1
  package_list=$(awk '!/^[[:space:]]*(#|$)/ { print $1 }' "$package_file")
  [ -n "$package_list" ] || die "no packages found in ${package_file}"

  old_ifs=$IFS
  IFS='
'
  set -f
  # Package names cannot contain whitespace; intentional splitting turns the
  # newline-delimited package list into arguments for apt-get.
  # shellcheck disable=SC2086
  set -- $package_list
  set +f
  IFS=$old_ifs

  printf '[apt] Installing packages:'
  printf ' %s' "$@"
  printf '\n'

  run_as_root env DEBIAN_FRONTEND=noninteractive \
    apt-get \
    -o Acquire::Retries=3 \
    -o DPkg::Lock::Timeout=60 \
    --yes \
    --no-install-recommends \
    install "$@"
}

operating_system=$(uname -s)
[ "${operating_system}" = 'Linux' ] || die 'this script only supports Linux'
command -v apt-get > /dev/null 2>&1 || die 'apt-get is required'

printf '%s\n' '[apt] Refreshing package metadata...'
apt_get update
install_packages "${script_dir}/essentials.apt"

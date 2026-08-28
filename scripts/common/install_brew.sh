#!/bin/sh

set -eu

installer=''

cleanup() {
  [ -z "$installer" ] || rm -f -- "$installer"
}

die() {
  printf '%s: %s\n' "$(basename "$0")" "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

load_brew_environment() {
  command_exists brew && return 0

  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [ -x "${prefix}/bin/brew" ]; then
      brew_environment=$("${prefix}/bin/brew" shellenv) || return 1
      eval "${brew_environment}" || return 1
      return 0
    fi
  done

  return 1
}

install_brew() {
  printf '%s\n' '[homebrew] Checking installation...'
  export HOMEBREW_NO_ANALYTICS=1

  if load_brew_environment; then
    brew analytics off
    printf '%s\n' '[homebrew] Already installed.'
    return 0
  fi

  command_exists curl || die 'curl is required to install Homebrew'
  command_exists bash || die 'bash is required by the Homebrew installer'

  installer=$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX") \
    || die 'could not create a temporary file'
  trap cleanup 0
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  curl --retry 3 -fsSL \
    'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' \
    -o "$installer"

  bash -n "$installer"
  NONINTERACTIVE=1 bash "$installer"
  load_brew_environment || die 'Homebrew was installed but could not be found'

  brew analytics off
  printf '%s\n' '[homebrew] Installation complete.'
}

install_brew

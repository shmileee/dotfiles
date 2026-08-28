#!/bin/sh

set -eu

readonly ansible_core_version="${ANSIBLE_CORE_VERSION:-2.21.3}"
program=${0##*/}

usage() {
  cat << EOF
Usage: ${program}

Install Ansible through Homebrew on macOS or as an isolated, pinned
ansible-core environment on Linux.

Environment:
  ANSIBLE_CORE_VERSION   Linux Ansible Core version (default: 2.21.3)
EOF
}

die() {
  printf '%s: %s\n' "${program}" "$*" >&2
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

install_with_brew() {
  load_brew_environment || die 'Homebrew is required to install Ansible'

  if brew list --formula ansible > /dev/null 2>&1; then
    printf '%s\n' '[ansible] Already installed.'
  else
    printf '%s\n' '[ansible] Installing with Homebrew...'
    brew install ansible
  fi
}

install_with_venv() {
  command_exists python3 || die 'python3 is required to install Ansible Core'

  data_home=${XDG_DATA_HOME:-${HOME}/.local/share}
  ansible_environment="${data_home}/dotfiles/ansible-core"
  ansible_playbook="${ansible_environment}/bin/ansible-playbook"
  installed_version=''

  if [ -x "${ansible_playbook}" ]; then
    installed_version=$("${ansible_playbook}" --version 2> /dev/null) \
      || installed_version=''
  fi

  case ${installed_version} in
    *"[core ${ansible_core_version}]"*) ansible_is_current=1 ;;
    *) ansible_is_current=0 ;;
  esac

  if [ "${ansible_is_current}" -eq 1 ]; then
    printf '[ansible] Core %s already installed.\n' "${ansible_core_version}"
    return 0
  fi

  printf '[ansible] Installing Core %s in an isolated environment...\n' \
    "${ansible_core_version}"
  mkdir -p "${data_home}/dotfiles"
  python3 -m venv "${ansible_environment}"
  "${ansible_environment}/bin/python" -m pip install \
    --disable-pip-version-check \
    --no-input \
    --upgrade \
    "ansible-core==${ansible_core_version}"
  [ -x "${ansible_playbook}" ] || die 'Ansible Core installation failed'

  installed_version=$("${ansible_playbook}" --version 2> /dev/null) \
    || die 'the installed ansible-playbook cannot be executed'
  case ${installed_version} in
    *"[core ${ansible_core_version}]"*) ;;
    *) die "installed Ansible Core version does not match ${ansible_core_version}" ;;
  esac
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

case ${1:-install} in
  install)
    operating_system=$(uname -s)
    case ${operating_system} in
      Darwin) install_with_brew ;;
      Linux) install_with_venv ;;
      *) die "unsupported operating system: ${operating_system}" ;;
    esac
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage >&2
    die "unknown option: $1"
    ;;
esac

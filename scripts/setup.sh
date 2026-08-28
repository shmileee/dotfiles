#!/bin/sh

set -eu

readonly repository_url="${DOTFILES_REPOSITORY_URL:-https://github.com/shmileee/dotfiles}"
readonly repository_branch="${DOTFILES_REF:-master}"
readonly repository_archive="${repository_url}/tarball/${repository_branch}"

repository=''
temporary_repository=''

usage() {
  cat << 'EOF'
Usage: setup.sh [OPTION]...

Set up this dotfiles repository on macOS or Linux.

Options:
  --deps       install Linux system dependencies
  --brew       install Homebrew
  --ansible    install Ansible collections and run the playbook
  --all        run the complete setup (default)
  -h, --help   display this help and exit

Environment:
  DOTFILES_REPOSITORY_URL   repository to download when run outside a checkout
  DOTFILES_REF              branch, tag, or commit to download (default: master)
  ANSIBLE_CORE_VERSION      Ansible Core version used on Linux (default: 2.21.3)
EOF
}

die() {
  printf 'setup.sh: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

platform() {
  uname -s
}

require_supported_platform() {
  case $1 in
    Darwin | Linux) ;;
    *) die "unsupported operating system: $1" ;;
  esac
}

cleanup() {
  if [ -n "$temporary_repository" ] && [ -d "$temporary_repository" ]; then
    rm -rf -- "$temporary_repository"
  fi
}

find_local_repository() {
  script_dir=$(CDPATH='' cd -P "$(dirname "$0")" && pwd)

  if [ -x "${script_dir}/common/ansible.sh" ]; then
    repository=$(CDPATH='' cd -P "${script_dir}/.." && pwd)
  fi
}

ensure_brew_in_path() {
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

activate_ansible() {
  operating_system=$(platform)
  case ${operating_system} in
    Darwin)
      ensure_brew_in_path || die 'Homebrew is installed but could not be found'
      ;;
    Linux)
      data_home=${XDG_DATA_HOME:-${HOME}/.local/share}
      PATH="${data_home}/dotfiles/ansible-core/bin:${PATH}"
      export PATH
      ;;
    *) die "unsupported operating system: ${operating_system}" ;;
  esac

  command_exists ansible-playbook || die 'Ansible installation could not be found'
}

configure_with_ansible() {
  "${repository}/scripts/common/install_brew.sh"
  "${repository}/scripts/common/install_ansible.sh"
  activate_ansible
  "${repository}/scripts/common/ansible.sh" --all
}

download_repository() {
  temporary_repository=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXX") \
    || die 'could not create a temporary directory'
  repository=$temporary_repository
  trap cleanup 0
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  if command_exists tar && { command_exists curl || command_exists wget; }; then
    archive_file="${temporary_repository}/repository.tar.gz"

    if command_exists curl; then
      curl --retry 3 -fsSL "$repository_archive" -o "$archive_file"
    else
      wget -qO "$archive_file" "$repository_archive"
    fi

    [ -s "$archive_file" ] || die 'downloaded repository archive is empty'
    tar -xzf "$archive_file" -C "$repository" --strip-components=1
    rm -f -- "$archive_file"
  elif command_exists git; then
    git -C "$repository" init --quiet
    git -C "$repository" remote add origin "$repository_url"
    git -C "$repository" fetch --quiet --depth 1 origin "$repository_branch"
    git -C "$repository" checkout --quiet --detach FETCH_HEAD
  else
    die 'tar and curl/wget, or git, are required to download the repository'
  fi

  [ -x "${repository}/scripts/common/ansible.sh" ] \
    || die 'downloaded repository is incomplete'
}

require_local_repository() {
  [ -n "$repository" ] \
    || die 'this option must be run from a repository checkout'
}

setup_all() {
  operating_system=$(platform)
  require_supported_platform "${operating_system}"

  [ -n "$repository" ] || download_repository

  if [ "$operating_system" = 'Linux' ]; then
    "${repository}/scripts/linux/install_dependencies.sh"
  fi

  configure_with_ansible
}

find_local_repository
[ "$#" -le 1 ] || {
  usage >&2
  die 'specify exactly one option'
}

action=${1:---all}
case ${action} in
  -h | --help)
    usage
    ;;
  --deps)
    require_local_repository
    operating_system=$(platform)
    [ "${operating_system}" = 'Linux' ] \
      || die '--deps is only supported on Linux'
    "${repository}/scripts/linux/install_dependencies.sh"
    ;;
  --brew)
    require_local_repository
    operating_system=$(platform)
    require_supported_platform "${operating_system}"
    "${repository}/scripts/common/install_brew.sh"
    ;;
  --ansible)
    require_local_repository
    operating_system=$(platform)
    require_supported_platform "${operating_system}"
    configure_with_ansible
    ;;
  --all)
    setup_all
    ;;
  *)
    usage >&2
    die "unknown option: ${action}"
    ;;
esac

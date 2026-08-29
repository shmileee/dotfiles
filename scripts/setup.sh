#!/bin/sh

set -eu

readonly repository_url="${DOTFILES_REPOSITORY_URL:-https://github.com/shmileee/dotfiles}"
readonly repository_ref="${DOTFILES_REF:-master}"
# renovate: datasource=github-releases depName=astral-sh/uv
readonly uv_version="${UV_BOOTSTRAP_VERSION:-0.12.6}"

data_home=${XDG_DATA_HOME:-${HOME}/.local/share}
readonly data_home
readonly managed_checkout="${DOTFILES_CHECKOUT:-${data_home}/dotfiles/repository}"
readonly bootstrap_bin="${data_home}/dotfiles/bootstrap/bin"

repository=''
staging_directory=''
installer=''
fetched_revision=''
fetched_branch=''

usage() {
  cat << 'EOF'
Usage: setup.sh

Configure this macOS or Debian workstation from the dotfiles repository.

Environment:
  DOTFILES_REPOSITORY_URL  repository used by the remote bootstrap
  DOTFILES_REF             branch, tag, or commit to install (default: master)
  DOTFILES_CHECKOUT        managed checkout location
  UV_BOOTSTRAP_VERSION     standalone uv version used to launch Ansible
EOF
}

die() {
  printf 'setup.sh: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

uv_version_matches() {
  case $1 in
    "uv ${uv_version}" | "uv ${uv_version} "*) return 0 ;;
    *) return 1 ;;
  esac
}

cleanup() {
  [ -z "$installer" ] || rm -f -- "$installer"
  [ -z "$staging_directory" ] || rm -rf -- "$staging_directory"
}

cleanup_on_signal() {
  exit "$1"
}

require_supported_platform() {
  case $(uname -s) in
    Darwin) ;;
    Linux)
      command_exists apt-get \
        || die 'Linux support currently requires a Debian-family system'
      ;;
    *) die 'only macOS and Debian-family Linux systems are supported' ;;
  esac
}

require_bootstrap_tools() {
  for executable in curl tar; do
    command_exists "$executable" || die "$executable is required"
  done
}

prime_privileges() {
  user_id=$(id -u)
  [ "$user_id" -ne 0 ] || return 0
  command_exists sudo || die 'root access or sudo is required'
  sudo -n true 2> /dev/null && return 0
  [ -r /dev/tty ] || die 'sudo authentication requires an interactive terminal'

  printf '%s\n' '[bootstrap] Authenticating administrator access...'
  # The shell program occupies stdin; sudo must read the password from the TTY.
  # shellcheck disable=SC2024
  sudo -v < /dev/tty
}

find_local_checkout() {
  # A piped shell sets $0 to a shell name. Only a script path proves that the
  # bootstrap itself came from a checkout rather than the caller's directory.
  case $0 in
    */*) ;;
    *) return 0 ;;
  esac

  script_directory=$(CDPATH='' cd -P "$(dirname "$0")" 2> /dev/null && pwd) \
    || return 0

  if [ -x "${script_directory}/common/ansible.sh" ]; then
    repository=$(CDPATH='' cd -P "${script_directory}/.." && pwd)
  fi
}

download_checkout() {
  parent_directory=${managed_checkout%/*}
  [ "$parent_directory" != "$managed_checkout" ] \
    || die 'DOTFILES_CHECKOUT must include a parent directory'
  mkdir -p -- "$parent_directory"

  if [ -d "${managed_checkout}/.git" ]; then
    repository=$managed_checkout
    return 0
  fi

  if [ -x "${managed_checkout}/scripts/common/ansible.sh" ]; then
    repository=$managed_checkout
    return 0
  fi

  if [ -e "$managed_checkout" ]; then
    die "managed checkout exists but is incomplete: ${managed_checkout}"
  fi

  staging_directory=$(mktemp -d "${parent_directory}/.repository.XXXXXX") \
    || die 'could not create the repository staging directory'
  archive_file="${staging_directory}/repository.tar.gz"

  printf '[bootstrap] Downloading %s at %s...\n' \
    "$repository_url" "$repository_ref"
  curl --retry 3 -fsSL \
    "${repository_url}/archive/${repository_ref}.tar.gz" \
    -o "$archive_file"
  [ -s "$archive_file" ] || die 'downloaded repository archive is empty'

  extract_directory="${staging_directory}/extracted"
  mkdir "$extract_directory"
  tar -xzf "$archive_file" -C "$extract_directory" --strip-components=1
  rm -f -- "$archive_file"
  [ -x "${extract_directory}/scripts/common/ansible.sh" ] \
    || die 'downloaded repository is incomplete'

  mv "$extract_directory" "$managed_checkout"
  rmdir "$staging_directory"
  staging_directory=''
  repository=$managed_checkout
}

refresh_managed_checkout() {
  [ "$repository" = "$managed_checkout" ] || return 0
  [ -d "${repository}/.git" ] || return 0

  if ! git -C "$repository" diff --quiet \
    || ! git -C "$repository" diff --cached --quiet; then
    die "managed checkout has local changes: ${repository}"
  fi

  printf '[bootstrap] Updating managed checkout to %s...\n' "$repository_ref"
  git -C "$repository" remote set-url origin "$repository_url"
  fetch_repository_ref
  checkout_repository_ref
}

fetch_repository_ref() {
  fetched_branch=''

  if git -C "$repository" ls-remote --quiet --exit-code \
    --heads origin "refs/heads/${repository_ref}" > /dev/null; then
    fetched_branch=$repository_ref
    fetched_revision="refs/remotes/origin/${repository_ref}"
    git -C "$repository" fetch --quiet --depth 1 origin \
      "+refs/heads/${repository_ref}:${fetched_revision}"
  else
    git -C "$repository" fetch --quiet --depth 1 origin "$repository_ref"
    fetched_revision=FETCH_HEAD
  fi
}

checkout_repository_ref() {
  if [ -n "$fetched_branch" ]; then
    git -C "$repository" checkout --quiet -B "$fetched_branch" "$fetched_revision"
    git -C "$repository" branch --quiet \
      --set-upstream-to="origin/${fetched_branch}" "$fetched_branch"
  else
    git -C "$repository" checkout --quiet --detach "$fetched_revision"
  fi
}

install_uv() {
  uv="${bootstrap_bin}/uv"
  installed_version=''

  if [ -x "$uv" ]; then
    installed_version=$("$uv" --version 2> /dev/null) || installed_version=''
  fi
  ! uv_version_matches "$installed_version" || return 0

  mkdir -p "$bootstrap_bin"
  installer=$(mktemp "${TMPDIR:-/tmp}/uv-install.XXXXXX") \
    || die 'could not create the uv installer file'

  printf '[bootstrap] Installing uv %s...\n' "$uv_version"
  curl --retry 3 -fsSL \
    "https://astral.sh/uv/${uv_version}/install.sh" \
    -o "$installer"
  UV_UNMANAGED_INSTALL="$bootstrap_bin" sh "$installer"
  rm -f -- "$installer"
  installer=''

  installed_version=$("$uv" --version) \
    || die 'the installed uv executable could not be run'
  uv_version_matches "$installed_version" \
    || die "uv ${uv_version} installation could not be verified"
}

materialize_git_checkout() {
  [ "$repository" = "$managed_checkout" ] || return 0
  [ ! -d "${repository}/.git" ] || return 0
  command_exists git || die 'Ansible completed without installing Git'

  printf '%s\n' '[bootstrap] Creating the durable Git checkout...'
  git -C "$repository" init --quiet
  git -C "$repository" remote add origin "$repository_url"
  fetch_repository_ref
  git -C "$repository" reset --quiet "$fetched_revision"
  git -C "$repository" diff --quiet \
    || die 'downloaded archive does not match the fetched Git revision'
  checkout_repository_ref
}

run_ansible() {
  PATH="${bootstrap_bin}:${PATH}"
  export PATH
  "${repository}/scripts/common/ansible.sh" --all
}

[ "$#" -eq 0 ] || case ${1:-} in
  -h | --help)
    [ "$#" -eq 1 ] || die '--help does not accept arguments'
    usage
    exit 0
    ;;
  *)
    usage >&2
    die 'setup does not accept stage options; it always configures the workstation'
    ;;
esac

trap cleanup 0
trap 'cleanup_on_signal 129' HUP
trap 'cleanup_on_signal 130' INT
trap 'cleanup_on_signal 143' TERM

require_supported_platform
require_bootstrap_tools
prime_privileges
find_local_checkout
[ -n "$repository" ] || download_checkout
refresh_managed_checkout
install_uv
run_ansible
materialize_git_checkout

printf '[bootstrap] Workstation configured from %s.\n' "$repository"

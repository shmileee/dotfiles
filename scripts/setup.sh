#!/bin/sh

set -eu

# Forks only need to change these two repository identity settings. Every
# checkout path and repository URL used by bootstrap is derived from them.
repository_slug=shmileee/dotfiles
repository_ref=master
bootstrap_url=https://oponomarov.com/d
repository_url=https://github.com/$repository_slug.git
repository_archive_url=https://github.com/$repository_slug/archive/refs/heads/$repository_ref.tar.gz
# renovate: datasource=github-releases depName=astral-sh/uv
uv_version=0.12.6

workspace=
source_root=
invocation_mode=streamed
platform=
uv_artifact=
uv_executable=
persistent_checkout=
insecure_bootstrap_transport=false

phase() {
  printf '[dotfiles] %s\n' "$1"
}

recovery_advice() {
  if [ -n "$persistent_checkout" ] && { [ -e "$persistent_checkout" ] || [ -L "$persistent_checkout" ]; }; then
    printf 'Inspect %s. If it is a valid incomplete clone, run:\n' "$persistent_checkout" >&2
    printf '  cd "%s" && ./scripts/setup.sh\n' "$persistent_checkout" >&2
  else
    printf 'After correcting the problem, run:\n' >&2
    printf '  curl -kfsSL %s | sh\n' "$bootstrap_url" >&2
  fi
}

fail() {
  failure_message=$1
  failure_status=${2:-1}
  [ "$failure_status" -ne 0 ] || failure_status=1
  printf '[dotfiles] Error: %s\n' "$failure_message" >&2
  recovery_advice
  exit "$failure_status"
}

cleanup() {
  cleanup_status=$?
  trap - 0

  if [ -n "$workspace" ]; then
    cleanup_path=$workspace
    workspace=
    if ! rm -rf "$cleanup_path"; then
      printf '[dotfiles] Warning: could not remove private workspace %s. Remove that exact path manually.\n' "$cleanup_path" >&2
    fi
  fi

  exit "$cleanup_status"
}

usage() {
  cat << 'EOF'
Usage: ./scripts/setup.sh [--print-config]

Bootstrap a supported workstation, or recover an incomplete bootstrap from
the persistent checkout. Normal ongoing management uses `mise run reconcile`.

--print-config  Print the derived repository identity without making changes.
EOF
}

print_config() {
  case ${HOME-} in
    /*) config_checkout=$HOME/ghq/personalgit/$repository_slug ;;
    *) config_checkout='<invalid HOME>' ;;
  esac
  printf 'repository_slug=%s\n' "$repository_slug"
  printf 'repository_ref=%s\n' "$repository_ref"
  printf 'bootstrap_url=%s\n' "$bootstrap_url"
  printf 'repository_url=%s\n' "$repository_url"
  printf 'persistent_checkout=%s\n' "$config_checkout"
}

validate_arguments() {
  case $# in
    0) ;;
    1)
      case $1 in
        --print-config)
          print_config
          exit 0
          ;;
        -h | --help)
          usage
          exit 0
          ;;
        *)
          usage >&2
          fail 'setup does not accept stage arguments; it always runs the complete playbook.' 2
          ;;
      esac
      ;;
    *)
      usage >&2
      fail 'setup does not accept stage arguments; it always runs the complete playbook.' 2
      ;;
  esac
}

validate_identity() {
  if ! user_id=$(id -u 2> /dev/null); then
    fail 'could not determine the effective user ID.'
  fi
  if [ "$user_id" -eq 0 ]; then
    fail 'do not run bootstrap as root or through sudo; run it as the workstation user.'
  fi

  case ${HOME-} in
    /*) ;;
    *) fail 'HOME must be a non-empty absolute path for the workstation user.' ;;
  esac
  if [ "$HOME" = / ] || [ ! -d "$HOME" ] || [ ! -w "$HOME" ]; then
    fail 'HOME must be an existing, writable user directory and must not be /.'
  fi

  persistent_checkout=$HOME/ghq/personalgit/$repository_slug
}

find_local_sources() {
  case $0 in
    */scripts/setup.sh)
      if script_directory=$(CDPATH='' cd -P "$(dirname "$0")" 2> /dev/null && pwd); then
        candidate_root=$(CDPATH='' cd -P "$script_directory/.." 2> /dev/null && pwd) || candidate_root=
        if [ -f "$candidate_root/bootstrap/uv.lock" ] && [ -f "$candidate_root/scripts/common/ansible/main.yaml" ]; then
          source_root=$candidate_root
          invocation_mode=local
        fi
      fi
      ;;
  esac
}

guard_streamed_target() {
  [ "$invocation_mode" = streamed ] || return 0
  if [ ! -e "$persistent_checkout" ] && [ ! -L "$persistent_checkout" ]; then
    return 0
  fi

  printf '[dotfiles] /d is only for a fresh workstation; %s already exists.\n' "$persistent_checkout" >&2
  if [ -f "$persistent_checkout/.git/dotfiles-bootstrap-complete" ]; then
    printf '[dotfiles] Ansible previously completed the runtime handoff. The receipt is advisory; run:\n' >&2
    printf '  cd "%s" && mise run reconcile\n' "$persistent_checkout" >&2
    printf '[dotfiles] If mise is missing or broken, recover with:\n' >&2
    printf '  cd "%s" && ./scripts/setup.sh\n' "$persistent_checkout" >&2
  else
    printf '[dotfiles] No completion receipt was found. Inspect the path; for a valid incomplete clone, run:\n' >&2
    printf '  cd "%s" && ./scripts/setup.sh\n' "$persistent_checkout" >&2
  fi
  exit 1
}

require_command() {
  if ! command -v "$1" > /dev/null 2>&1; then
    fail "$1 is a required base-system command and must be installed manually."
  fi
}

read_linux_distribution() {
  os_release_file=${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}
  if [ ! -r "$os_release_file" ]; then
    fail "cannot read $os_release_file to identify the Linux distribution."
  fi

  linux_id=$(sed -n 's/^ID=["'\'']\{0,1\}\([^"'\'']*\)["'\'']\{0,1\}$/\1/p' "$os_release_file" | sed -n '1p')
  if [ "$linux_id" != ubuntu ]; then
    fail "unsupported Linux distribution: Ubuntu ARM64 is required (found ${linux_id:-unknown})."
  fi
}

detect_platform() {
  for base_command in uname sed tar curl mkdir rm id; do
    require_command "$base_command"
  done

  operating_system=$(uname -s)
  architecture=$(uname -m)
  case $operating_system in
    Darwin)
      if [ "$architecture" != arm64 ]; then
        fail "unsupported macOS architecture $architecture; Apple Silicon arm64 is required."
      fi
      require_command xcode-select
      if ! xcode-select -p > /dev/null 2>&1; then
        fail 'Apple Command Line Tools are required. Run xcode-select --install, finish the installation, then retry.'
      fi
      platform=macos
      uv_artifact=aarch64-apple-darwin
      ;;
    Linux)
      read_linux_distribution
      if [ "$architecture" != aarch64 ] && [ "$architecture" != arm64 ]; then
        fail "unsupported Ubuntu architecture $architecture; ARM64 aarch64 is required."
      fi
      platform=ubuntu
      uv_artifact=aarch64-unknown-linux-gnu
      ;;
    *)
      fail "unsupported operating system $operating_system; use Apple Silicon macOS or Ubuntu ARM64."
      ;;
  esac

  ca_bundle_file=${DOTFILES_CA_BUNDLE_FILE:-/etc/ssl/certs/ca-certificates.crt}
  if [ "$platform" = ubuntu ] && [ ! -s "$ca_bundle_file" ]; then
    insecure_bootstrap_transport=true
  fi

  require_command sudo
}

download_file() {
  download_destination=$1
  download_url=$2
  if [ "$insecure_bootstrap_transport" = true ]; then
    curl -kfsSL --retry 3 --output "$download_destination" "$download_url"
  else
    curl -fsSL --retry 3 --output "$download_destination" "$download_url"
  fi
}

create_workspace() {
  temporary_parent=${TMPDIR:-/tmp}
  case $temporary_parent in
    /*) ;;
    *) fail 'TMPDIR must be an absolute path.' ;;
  esac
  if [ ! -d "$temporary_parent" ] || [ ! -w "$temporary_parent" ]; then
    fail "temporary directory $temporary_parent must exist and be writable."
  fi

  attempt=1
  while [ "$attempt" -le 100 ]; do
    workspace_candidate=$temporary_parent/dotfiles-bootstrap.$$.$attempt
    if mkdir -m 700 "$workspace_candidate" 2> /dev/null; then
      workspace=$workspace_candidate
      return 0
    fi
    attempt=$((attempt + 1))
  done
  fail "could not claim a private workspace beneath $temporary_parent."
}

stage_sources() {
  [ "$invocation_mode" = streamed ] || return 0
  phase "Staging streamed $repository_ref sources"
  source_root=$workspace/source
  archive_path=$workspace/source.tar.gz
  mkdir "$source_root"

  if download_file "$archive_path" "$repository_archive_url"; then
    :
  else
    stage_status=$?
    fail "could not download the $repository_ref source archive; curl diagnostics are shown above." "$stage_status"
  fi
  if tar -xzf "$archive_path" -C "$source_root" --strip-components=1; then
    :
  else
    stage_status=$?
    fail 'could not extract the downloaded source archive; tar diagnostics are shown above.' "$stage_status"
  fi
  if [ ! -f "$source_root/bootstrap/uv.lock" ] || [ ! -f "$source_root/scripts/common/ansible/main.yaml" ]; then
    fail 'the downloaded archive does not contain the locked bootstrap project and playbook.'
  fi
  rm -f "$archive_path"
}

download_uv() {
  phase "Downloading pinned uv $uv_version for $platform"
  uv_archive=$workspace/uv.tar.gz
  uv_url=https://github.com/astral-sh/uv/releases/download/$uv_version/uv-$uv_artifact.tar.gz

  if download_file "$uv_archive" "$uv_url"; then
    :
  else
    uv_status=$?
    fail "could not download pinned uv $uv_version; curl diagnostics are shown above." "$uv_status"
  fi
  if tar -xzf "$uv_archive" -C "$workspace"; then
    :
  else
    uv_status=$?
    fail 'could not extract the pinned uv archive; tar diagnostics are shown above.' "$uv_status"
  fi
  uv_executable=$workspace/uv-$uv_artifact/uv
  if [ ! -x "$uv_executable" ]; then
    fail "the uv archive did not contain the expected $uv_artifact executable."
  fi
  if uv_report=$("$uv_executable" --version 2>&1); then
    :
  else
    uv_status=$?
    printf '%s\n' "$uv_report" >&2
    fail 'the downloaded uv executable could not report its version.' "$uv_status"
  fi
  case $uv_report in
    "uv $uv_version" | "uv $uv_version "*) ;;
    *) fail "uv version validation failed: expected $uv_version but received '$uv_report'." ;;
  esac

  UV_PYTHON_INSTALL_DIR=$workspace/python
  UV_PROJECT_ENVIRONMENT=$workspace/venv
  ANSIBLE_COLLECTIONS_PATH=$workspace/collections
  DOTFILES_BOOTSTRAP_WORKSPACE=$workspace
  DOTFILES_PERSISTENT_CHECKOUT=$persistent_checkout
  DOTFILES_PERSISTENT_REPOSITORY_URL=$repository_url
  DOTFILES_PERSISTENT_REF=${DOTFILES_PERSISTENT_REF:-$repository_ref}
  export UV_PYTHON_INSTALL_DIR UV_PROJECT_ENVIRONMENT ANSIBLE_COLLECTIONS_PATH
  export DOTFILES_BOOTSTRAP_WORKSPACE DOTFILES_PERSISTENT_CHECKOUT
  export DOTFILES_PERSISTENT_REPOSITORY_URL DOTFILES_PERSISTENT_REF
  mkdir -p "$ANSIBLE_COLLECTIONS_PATH"
}

run_bootstrap_runtime() {
  "$uv_executable" run --project "$source_root/bootstrap" --locked --managed-python \
    env -u UV_PYTHON_INSTALL_DIR -u UV_PROJECT_ENVIRONMENT "$@"
}

install_bootstrap_collections() {
  run_bootstrap_runtime ansible-galaxy collection install "$@" \
    --collections-path "$ANSIBLE_COLLECTIONS_PATH" \
    --requirements-file "$source_root/scripts/common/ansible/requirements.yml"
}

prepare_ansible() {
  phase 'Synchronizing the locked managed-Python controller'
  if "$uv_executable" sync --project "$source_root/bootstrap" --locked --managed-python; then
    :
  else
    runtime_status=$?
    fail 'uv could not synchronize bootstrap/uv.lock; its diagnostics are shown above.' "$runtime_status"
  fi

  phase 'Installing exactly pinned Ansible collections'
  galaxy_status=0
  if [ "$insecure_bootstrap_transport" = true ]; then
    install_bootstrap_collections --ignore-certs || galaxy_status=$?
  else
    install_bootstrap_collections || galaxy_status=$?
  fi
  if [ "$galaxy_status" -eq 0 ]; then
    :
  else
    fail 'Ansible Galaxy could not install the pinned collections; its diagnostics are shown above.' "$galaxy_status"
  fi

  phase 'Locked controller versions'
  printf 'requested repository ref: %s\n' "$repository_ref"
  if run_bootstrap_runtime python "$source_root/scripts/validate_bootstrap_runtime.py" \
    --uv-executable "$uv_executable" \
    --collections-path "$ANSIBLE_COLLECTIONS_PATH" \
    --checkout "$persistent_checkout"; then
    :
  else
    runtime_status=$?
    fail 'the locked controller identity does not match the repository manifests; validation diagnostics are shown above.' "$runtime_status"
  fi
}

run_ansible() {
  phase 'Running the complete workstation playbook'
  ANSIBLE_CONFIG=$source_root/scripts/common/ansible/ansible.cfg
  export ANSIBLE_CONFIG
  if ! workstation_user=$(id -un 2> /dev/null); then
    fail 'could not determine the workstation user name before Ansible.'
  fi

  if sudo -k -n true > /dev/null 2>&1; then
    if run_bootstrap_runtime ansible-playbook --inventory '127.0.0.1,' \
      -e "ansible_user=$workstation_user" \
      "$source_root/scripts/common/ansible/main.yaml"; then
      return 0
    else
      ansible_status=$?
    fi
  else
    phase 'Sudo needs the workstation password; Ansible will ask once'
    if run_bootstrap_runtime ansible-playbook --inventory '127.0.0.1,' \
      -e "ansible_user=$workstation_user" \
      "$source_root/scripts/common/ansible/main.yaml" \
      --ask-become-pass; then
      return 0
    else
      ansible_status=$?
    fi
  fi

  fail 'Ansible stopped before workstation provisioning completed; durable changes and any checkout were left in place.' "$ansible_status"
}

main() {
  validate_arguments "$@"
  validate_identity
  find_local_sources
  guard_streamed_target
  detect_platform
  create_workspace
  stage_sources
  download_uv
  prepare_ansible
  run_ansible
  phase "Workstation configured; future reconciliation uses $persistent_checkout"
  printf 'Next command: cd "%s" && mise run reconcile\n' "$persistent_checkout"
}

trap cleanup 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

main "$@"

#!/bin/sh

set -eu

script_directory=$(CDPATH='' cd -P "$(dirname "$0")" && pwd)
repository_root=$(CDPATH='' cd -P "$script_directory/../.." && pwd)
project=$repository_root/bootstrap
runtime_state=$project/.ansible
collections=$runtime_state/collections
collection_requirements=$script_directory/ansible/requirements.yml
collection_snapshot=$runtime_state/requirements.yml
collection_manifest_changed=false
check_mode=false

usage() {
  printf 'Usage: %s [--check]\n' "$0"
}

case $# in
  0) ;;
  1)
    case $1 in
      --check) check_mode=true ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

command -v uv > /dev/null 2>&1 || {
  printf 'uv is missing. Recover with ./scripts/setup.sh from the persistent checkout.\n' >&2
  exit 1
}
command -v sudo > /dev/null 2>&1 || {
  printf 'sudo is required to reconcile this workstation.\n' >&2
  exit 1
}

UV_PROJECT_ENVIRONMENT=$project/.venv
ANSIBLE_COLLECTIONS_PATH=$collections
DOTFILES_PERSISTENT_CHECKOUT=$repository_root
ANSIBLE_CONFIG=$script_directory/ansible/ansible.cfg
export UV_PROJECT_ENVIRONMENT ANSIBLE_COLLECTIONS_PATH
export DOTFILES_PERSISTENT_CHECKOUT ANSIBLE_CONFIG

if [ -L "$runtime_state" ] || [ -L "$collections" ] || [ -L "$collection_snapshot" ]; then
  printf 'Refusing to replace reconciliation state through a symbolic link beneath %s.\n' "$runtime_state" >&2
  exit 1
fi
mkdir -p "$runtime_state"

# Galaxy installs requested versions but does not prune collections removed from
# the requirements file. Rebuild this repository-owned path only when its exact
# manifest changes so runtime validation cannot be blocked by obsolete content.
if [ ! -d "$collections" ] || [ ! -f "$collection_snapshot" ] \
  || ! cmp -s "$collection_requirements" "$collection_snapshot"; then
  collection_manifest_changed=true
  rm -rf "$collections"
fi
mkdir -p "$collections"

run_in_runtime() {
  uv run --project "$project" --locked --managed-python "$@"
}

printf '[dotfiles] Synchronizing locked reconciliation runtime\n'
uv sync --project "$project" --locked --managed-python

printf '[dotfiles] Installing exactly pinned Ansible collections\n'
run_in_runtime ansible-galaxy collection install \
  --collections-path "$collections" \
  --requirements-file "$collection_requirements"

printf '[dotfiles] Validating locked runtime identity\n'
run_in_runtime python "$repository_root/scripts/validate_bootstrap_runtime.py" \
  --uv-executable "$(command -v uv)" \
  --collections-path "$collections" \
  --checkout "$repository_root"
if [ "$collection_manifest_changed" = true ]; then
  cp "$collection_requirements" "$collection_snapshot"
fi

set -- ansible-playbook --inventory '127.0.0.1,' \
  -e "ansible_user=$(id -un)" "$script_directory/ansible/main.yaml"
if [ "$check_mode" = true ]; then
  set -- "$@" --check
fi

# Invalidate cached credentials so this distinguishes configured passwordless
# sudo from a timestamp left by an earlier command.
if ! sudo -k -n true > /dev/null 2>&1; then
  set -- "$@" --ask-become-pass
fi

printf '[dotfiles] Running complete workstation playbook\n'
run_in_runtime "$@"

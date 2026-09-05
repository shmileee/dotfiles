#!/bin/sh

set -eu

printf 'uv %s\n' "$*" >> "$MOCK_LOG"
if [ -n "${DOTFILES_BOOTSTRAP_WORKSPACE:-}" ]; then
  if workspace_mode=$(stat -c %a "$DOTFILES_BOOTSTRAP_WORKSPACE" 2> /dev/null); then
    :
  else
    workspace_mode=$(stat -f %Lp "$DOTFILES_BOOTSTRAP_WORKSPACE")
  fi
  {
    printf 'workspace=%s\n' "$DOTFILES_BOOTSTRAP_WORKSPACE"
    printf 'workspace_mode=%s\n' "$workspace_mode"
    printf 'python_install=%s\n' "${UV_PYTHON_INSTALL_DIR:-unset}"
    printf 'project_environment=%s\n' "${UV_PROJECT_ENVIRONMENT:-unset}"
    printf 'collections=%s\n' "${ANSIBLE_COLLECTIONS_PATH:-unset}"
    printf 'uv_cache=%s\n' "${UV_CACHE_DIR:-unset}"
  } >> "$MOCK_LOG"
fi

if [ "${1:-}" = --version ]; then
  printf 'uv %s\n' "${TEST_UV_REPORTED_VERSION:?}"
  exit "${TEST_UV_VERSION_STATUS:-0}"
fi

case " $* " in
  *" ansible-galaxy collection install "*)
    if [ -n "${TEST_GALAXY_FAIL_ATTEMPTS:-}" ]; then
      galaxy_attempt=$(($(cat "$MOCK_LOG.galaxy-attempts" 2> /dev/null || printf 0) + 1))
      printf '%s\n' "$galaxy_attempt" > "$MOCK_LOG.galaxy-attempts"
      [ "$galaxy_attempt" -gt "$TEST_GALAXY_FAIL_ATTEMPTS" ] || exit 1
      exit 0
    fi
    exit "${TEST_GALAXY_STATUS:-0}"
    ;;
  *" ansible-galaxy collection list "*)
    printf '%s\n' 'installed collections available'
    ;;
  *" python "*"/bootstrap/validate_runtime.py "*)
    exit "${TEST_RUNTIME_VALIDATION_STATUS:-0}"
    ;;
  *" ansible-playbook --version "*)
    printf '%s\n' 'ansible-playbook available'
    ;;
  *" ansible-playbook "*"/bootstrap/ansible/main.yaml "*)
    exit "${TEST_ANSIBLE_STATUS:-0}"
    ;;
  *" python --version "*)
    printf '%s\n' 'Python available'
    ;;
  *" sync "*)
    exit "${TEST_SYNC_STATUS:-0}"
    ;;
esac

exit 0

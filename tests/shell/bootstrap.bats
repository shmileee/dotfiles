#!/usr/bin/env bats

# Bats provides status/output/lines, the helper initializes test paths, and
# single-quoted mock bodies are intentionally expanded by the generated shell.
# shellcheck disable=SC2016,SC2154

load test_helper.bash

setup() {
  setup_test_environment
}

teardown() {
  teardown_test_environment
}

function setup_displays_help_under_dash { #@test
  run dash "${project_root}/scripts/setup.sh" --help

  [ "${status}" -eq 0 ]
  [[ ${output} == *'Usage: setup.sh'* ]]
  [[ ${output} == *'DOTFILES_REF'* ]]
}

function setup_rejects_multiple_actions { #@test
  run dash "${project_root}/scripts/setup.sh" --brew --ansible

  [ "${status}" -eq 1 ]
  [[ ${output} == *'specify exactly one option'* ]]
}

function linux_bootstrap_uses_native_prerequisites_and_isolated_ansible { #@test
  make_mock uname 'printf "%s\n" Linux'
  make_mock id '
    case ${1:-} in
      -u) printf "%s\n" 1000 ;;
      -un) printf "%s\n" dotfiles-test ;;
      *) exit 64 ;;
    esac
  '
  make_mock sudo '
    if [ "${1:-}" = -n ]; then
      exit 0
    fi
    printf "sudo %s\n" "$*" >>"${MOCK_LOG}"
    "$@"
  '
  make_mock apt-get 'printf "apt-get %s\n" "$*" >>"${MOCK_LOG}"'
  make_mock brew '
    printf "brew %s\n" "$*" >>"${MOCK_LOG}"
  '
  make_mock ansible-galaxy \
    'printf "ansible-galaxy %s\n" "$*" >>"${MOCK_LOG}"'
  make_mock ansible-playbook \
    '
      if [ "${1:-}" = --version ]; then
        printf "ansible [core %s]\n" "${TEST_ANSIBLE_VERSION}"
      else
        printf "ansible-playbook %s\n" "$*" >>"${MOCK_LOG}"
      fi
    '
  make_mock venv-python \
    'printf "python %s\n" "$*" >>"${MOCK_LOG}"'
  make_mock python3 '
    [ "$1" = -m ] && [ "$2" = venv ]
    environment=$3
    mkdir -p "${environment}/bin"
    ln -s "${mock_bin}/venv-python" "${environment}/bin/python"
    ln -s "${mock_bin}/ansible-galaxy" "${environment}/bin/ansible-galaxy"
    ln -s "${mock_bin}/ansible-playbook" "${environment}/bin/ansible-playbook"
    printf "python3 %s\n" "$*" >>"${MOCK_LOG}"
  '
  mkdir -p "${test_root}/home"

  run env CI=1 HOME="${test_root}/home" \
    ANSIBLE_CORE_VERSION="${TEST_ANSIBLE_VERSION}" \
    dash "${project_root}/scripts/setup.sh" --all

  [ "${status}" -eq 0 ]
  assert_log_contains 'Acquire::Retries=3 -o DPkg::Lock::Timeout=60 update'
  assert_log_contains '--yes --no-install-recommends install'
  refute_log_contains 'software-properties-common'
  refute_log_contains 'ppa:ansible/ansible'
  assert_log_contains 'python3 -m venv'
  assert_log_contains "ansible-core==${TEST_ANSIBLE_VERSION}"
  refute_log_contains 'brew install ansible'
  assert_log_contains 'ansible-galaxy collection install'
  assert_log_contains 'ansible-playbook --inventory 127.0.0.1,'
}

function matching_linux_ansible_environment_is_reused { #@test
  make_mock uname 'printf "%s\n" Linux'
  make_mock current-ansible '
    case ${1:-} in
      --version) printf "ansible [core %s]\n" "${TEST_ANSIBLE_VERSION}" ;;
      *) exit 64 ;;
    esac
  '
  make_mock python3 'exit 99'
  environment="${test_root}/home/.local/share/dotfiles/ansible-core/bin"
  mkdir -p "${environment}"
  ln -s "${mock_bin}/current-ansible" "${environment}/ansible-playbook"

  run env HOME="${test_root}/home" \
    ANSIBLE_CORE_VERSION="${TEST_ANSIBLE_VERSION}" \
    dash "${project_root}/scripts/common/install_ansible.sh"

  [ "${status}" -eq 0 ]
  [[ ${output} == *"Core ${TEST_ANSIBLE_VERSION} already installed."* ]]
}

function ansible_version_match_is_exact { #@test
  make_mock uname 'printf "%s\n" Linux'
  make_mock current-ansible '
    case ${1:-} in
      --version) printf "ansible [core %s0]\n" "${TEST_ANSIBLE_VERSION}" ;;
      *) exit 64 ;;
    esac
  '
  make_mock installed-ansible '
    case ${1:-} in
      --version) printf "ansible [core %s]\n" "${TEST_ANSIBLE_VERSION}" ;;
      *) exit 64 ;;
    esac
  '
  make_mock venv-python 'exit 0'
  make_mock python3 '
    environment=$3
    printf "python3 %s\n" "$*" >>"${MOCK_LOG}"
    mkdir -p "${environment}/bin"
    ln -sf "${mock_bin}/venv-python" "${environment}/bin/python"
    ln -sf "${mock_bin}/installed-ansible" "${environment}/bin/ansible-playbook"
  '
  environment="${test_root}/home/.local/share/dotfiles/ansible-core/bin"
  mkdir -p "${environment}"
  ln -s "${mock_bin}/current-ansible" "${environment}/ansible-playbook"

  run env HOME="${test_root}/home" \
    ANSIBLE_CORE_VERSION="${TEST_ANSIBLE_VERSION}" \
    dash "${project_root}/scripts/common/install_ansible.sh"

  [ "${status}" -eq 0 ]
  assert_log_contains 'python3 -m venv'
}

function linux_playbook_requests_password_even_when_fish_is_login_shell { #@test
  make_mock uname 'printf "%s\n" Linux'
  make_mock id '
    case ${1:-} in
      -u) printf "%s\n" 1000 ;;
      -un) printf "%s\n" dotfiles-test ;;
      *) exit 64 ;;
    esac
  '
  make_mock sudo 'exit 1'
  make_mock ansible-playbook \
    'printf "ansible-playbook %s\n" "$*" >>"${MOCK_LOG}"'

  run env CI=1 dash "${project_root}/scripts/common/ansible.sh" --run

  [ "${status}" -eq 0 ]
  assert_log_contains '--ask-become-pass'
}

function installed_homebrew_only_disables_analytics { #@test
  make_mock brew 'printf "brew %s\n" "$*" >>"${MOCK_LOG}"'
  make_mock curl 'exit 99'
  make_mock bash 'exit 98'

  run dash "${project_root}/scripts/common/install_brew.sh"

  [ "${status}" -eq 0 ]
  [[ ${output} == *'Already installed.'* ]]
  assert_log_contains 'brew analytics off'
}

function standalone_bootstrap_propagates_download_failure { #@test
  cp "${project_root}/scripts/setup.sh" "${test_root}/setup.sh"
  make_mock uname 'printf "%s\n" Linux'
  make_mock curl 'exit 22'

  run env DOTFILES_REF=test-ref dash "${test_root}/setup.sh" --all

  [ "${status}" -eq 22 ]
}

function profile_reports_and_preserves_command_status { #@test
  run dash "${project_root}/scripts/docker/profile.sh" test-phase sh -c 'exit 23'

  [ "${status}" -eq 23 ]
  [[ ${lines[0]} == 'PROFILE phase=test-phase status=started' ]]
  [[ ${lines[1]} =~ ^PROFILE\ phase=test-phase\ status=23\ elapsed_seconds=[0-9]+$ ]]
}

function docker_smoke_uses_the_standalone_posix_payload { #@test
  make_mock docker 'printf "docker %s\n" "$*" >>"${MOCK_LOG}"'

  run dash "${project_root}/scripts/docker/smoke.sh" dotfiles:test

  [ "${status}" -eq 0 ]
  assert_log_contains \
    'docker run --rm --entrypoint /bin/sh dotfiles:test /tmp/.dotfiles/scripts/docker/container-smoke.sh'
}

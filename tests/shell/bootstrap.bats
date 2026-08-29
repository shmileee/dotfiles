#!/usr/bin/env bats

# Bats provides status/output/lines, and the helper initializes test paths.
# shellcheck disable=SC2016,SC2154

load test_helper.bash

setup() {
  setup_test_environment
}

teardown() {
  teardown_test_environment
}

install_common_bootstrap_mocks() {
  local operating_system=$1

  make_mock uname "printf '%s\\n' ${operating_system}"
  make_mock id '
    case ${1:-} in
      -u) printf "%s\n" 1000 ;;
      -un) printf "%s\n" dotfiles-test ;;
      *) exit 64 ;;
    esac
  '
  make_mock sudo '
    [ "${1:-}" = -n ] && [ "${2:-}" = true ]
  '
  make_mock apt-get 'exit 0'
  make_mock curl '
    output=""
    while [ "$#" -gt 0 ]; do
      case $1 in
        -o) output=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    cat > "$output" <<'"'"'INSTALLER'"'"'
#!/bin/sh
cat > "${UV_UNMANAGED_INSTALL}/uv" <<'"'"'UV'"'"'
#!/bin/sh
if [ "${1:-}" = --version ]; then
  printf "uv %s\n" "${TEST_UV_VERSION}"
  exit 0
fi
printf "uv %s\n" "$*" >> "${MOCK_LOG}"
UV
chmod +x "${UV_UNMANAGED_INSTALL}/uv"
INSTALLER
  '
}

function setup_displays_help_under_dash { #@test
  run dash "${project_root}/scripts/setup.sh" --help

  [ "${status}" -eq 0 ]
  [[ ${output} == *'Usage: setup.sh'* ]]
  [[ ${output} == *'DOTFILES_CHECKOUT'* ]]
}

function setup_rejects_public_stage_options { #@test
  run dash "${project_root}/scripts/setup.sh" --all

  [ "${status}" -eq 1 ]
  [[ ${output} == *'always configures the workstation'* ]]
}

function linux_and_macos_use_the_same_uv_ansible_path { #@test
  local operating_system

  for operating_system in Linux Darwin; do
    : > "${mock_log}"
    rm -rf -- "${test_root:?}/home"
    mkdir -p "${test_root}/home"
    install_common_bootstrap_mocks "${operating_system}"

    run env HOME="${test_root}/home" \
      TEST_UV_VERSION='99.88.77' \
      UV_BOOTSTRAP_VERSION='99.88.77' \
      dash "${project_root}/scripts/setup.sh"

    [ "${status}" -eq 0 ]
    assert_log_contains 'uv sync --locked --project'
    assert_log_contains 'uv run --locked --project'
    assert_log_contains 'ansible-galaxy collection install'
    assert_log_contains 'ansible-playbook --inventory 127.0.0.1,'
    refute_log_contains 'brew install ansible'
    refute_log_contains 'python3 -m venv'
  done
}

function matching_bootstrap_uv_is_reused { #@test
  make_mock uname 'printf "%s\n" Darwin'
  make_mock id 'printf "%s\n" 0'
  make_mock curl 'exit 99'
  mkdir -p "${test_root}/home/.local/share/dotfiles/bootstrap/bin"
  make_mock uv-runtime '
    if [ "${1:-}" = --version ]; then
      printf "%s\n" "uv 99.88.77"
    else
      printf "uv %s\n" "$*" >> "${MOCK_LOG}"
    fi
  '
  cp "${mock_bin}/uv-runtime" \
    "${test_root}/home/.local/share/dotfiles/bootstrap/bin/uv"

  run env HOME="${test_root}/home" \
    UV_BOOTSTRAP_VERSION='99.88.77' \
    dash "${project_root}/scripts/setup.sh"

  [ "${status}" -eq 0 ]
  refute_log_contains 'curl'
  assert_log_contains 'uv sync --locked --project'
}

function remote_bootstrap_creates_a_durable_checkout { #@test
  cp "${project_root}/scripts/setup.sh" "${test_root}/setup.sh"
  mkdir -p "${test_root}/caller/scripts/common"
  printf '#!/bin/sh\nexit 97\n' \
    > "${test_root}/caller/scripts/common/ansible.sh"
  chmod +x "${test_root}/caller/scripts/common/ansible.sh"
  make_mock uname 'printf "%s\n" Linux'
  make_mock id 'printf "%s\n" 0'
  make_mock apt-get 'exit 0'
  make_mock curl '
    output=""
    url=""
    while [ "$#" -gt 0 ]; do
      case $1 in
        -o) output=$2; shift 2 ;;
        http*) url=$1; shift ;;
        *) shift ;;
      esac
    done
    printf "curl %s\n" "$url" >> "${MOCK_LOG}"
    case $url in
      *astral.sh*)
        cat > "$output" <<'"'"'INSTALLER'"'"'
#!/bin/sh
cat > "${UV_UNMANAGED_INSTALL}/uv" <<'"'"'UV'"'"'
#!/bin/sh
[ "${1:-}" != --version ] || { printf "uv 99.88.77\n"; exit; }
printf "uv %s\n" "$*" >> "${MOCK_LOG}"
UV
chmod +x "${UV_UNMANAGED_INSTALL}/uv"
INSTALLER
        ;;
      *) printf "%s\n" archive > "$output" ;;
    esac
  '
  make_mock tar '
    while [ "$#" -gt 0 ]; do
      case $1 in
        -C) destination=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "${destination}/scripts/common"
    cat > "${destination}/scripts/common/ansible.sh" <<'"'"'ANSIBLE'"'"'
#!/bin/sh
printf "ansible %s\n" "$*" >> "${MOCK_LOG}"
ANSIBLE
    chmod +x "${destination}/scripts/common/ansible.sh"
  '
  make_mock git '
    directory=""
    if [ "${1:-}" = -C ]; then
      directory=$2
      shift 2
    fi
    printf "git %s\n" "$*" >> "${MOCK_LOG}"
    [ "${1:-}" != init ] || mkdir -p "${directory}/.git"
  '

  checkout="${test_root}/home/dotfiles"
  run env HOME="${test_root}/home" \
    CALLER="${test_root}/caller" \
    DOTFILES_CHECKOUT="${checkout}" \
    DOTFILES_REF='test-ref' \
    DOTFILES_REPOSITORY_URL='https://example.test/dotfiles' \
    SCRIPT="${test_root}/setup.sh" \
    UV_BOOTSTRAP_VERSION='99.88.77' \
    dash -c 'cd "$CALLER" && dash < "$SCRIPT"'

  [ "${status}" -eq 0 ]
  [ -d "${checkout}/.git" ]
  assert_log_contains \
    'curl https://example.test/dotfiles/archive/test-ref.tar.gz'
  assert_log_contains 'ansible --all'
  assert_log_contains \
    'git fetch --quiet --depth 1 origin +refs/heads/test-ref:refs/remotes/origin/test-ref'
}

function standalone_bootstrap_propagates_download_failure { #@test
  cp "${project_root}/scripts/setup.sh" "${test_root}/setup.sh"
  make_mock uname 'printf "%s\n" Linux'
  make_mock id 'printf "%s\n" 0'
  make_mock apt-get 'exit 0'
  make_mock curl 'exit 22'

  run env HOME="${test_root}/home" \
    DOTFILES_CHECKOUT="${test_root}/home/dotfiles" \
    dash "${test_root}/setup.sh"

  [ "${status}" -eq 22 ]
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
  make_mock uv 'printf "uv %s\n" "$*" >> "${MOCK_LOG}"'

  run env CI=1 HOME="${test_root}/home" \
    dash "${project_root}/scripts/common/ansible.sh" --run

  [ "${status}" -eq 0 ]
  assert_log_contains 'ansible-playbook --inventory 127.0.0.1,'
  assert_log_contains '--ask-become-pass'
}

function installed_homebrew_only_disables_analytics { #@test
  make_mock brew 'printf "brew %s\n" "$*" >> "${MOCK_LOG}"'
  make_mock curl 'exit 99'
  make_mock bash 'exit 98'

  run dash "${project_root}/scripts/common/install_brew.sh"

  [ "${status}" -eq 0 ]
  [[ ${output} == *'Already installed.'* ]]
  assert_log_contains 'brew analytics off'
}

function profile_reports_and_preserves_command_status { #@test
  run dash "${project_root}/scripts/docker/profile.sh" test-phase sh -c 'exit 23'

  [ "${status}" -eq 23 ]
  [[ ${lines[0]} == 'PROFILE phase=test-phase status=started' ]]
  [[ ${lines[1]} =~ ^PROFILE\ phase=test-phase\ status=23\ elapsed_seconds=[0-9]+$ ]]
}

function docker_smoke_uses_the_standalone_posix_payload { #@test
  make_mock docker 'printf "docker %s\n" "$*" >> "${MOCK_LOG}"'

  run dash "${project_root}/scripts/docker/smoke.sh" dotfiles:test

  [ "${status}" -eq 0 ]
  assert_log_contains \
    'docker run --rm --entrypoint /bin/sh dotfiles:test /tmp/.dotfiles/scripts/docker/container-smoke.sh'
}

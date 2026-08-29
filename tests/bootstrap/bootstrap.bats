#!/usr/bin/env bats

# Bats exposes setup fixtures as globals and passes TEST_* controls to helpers.
# shellcheck disable=SC2034,SC2154

load test-helper.bash

setup() {
  setup_bootstrap_test
}

teardown() {
  teardown_bootstrap_test
}

@test "the public loader parses under Dash and /bin/sh" {
  run "$dash_path" -n "$project_root/scripts/setup.sh"
  [ "$status" -eq 0 ]

  run /bin/sh -n "$project_root/scripts/setup.sh"
  [ "$status" -eq 0 ]
}

@test "root is rejected before platform probes or mutation" {
  TEST_ID_UID=0

  run_bootstrap

  [ "$status" -eq 1 ]
  [[ $output == *"do not run bootstrap as root"* ]]
  refute_log_contains "uname"
  refute_log_contains "curl"
  [ -z "$(find "$test_tmp" -mindepth 1 -print -quit)" ]
}

@test "empty and relative HOME values are rejected" {
  TEST_HOME_OVERRIDE=
  run_bootstrap
  [ "$status" -eq 1 ]
  [[ $output == *"HOME must be a non-empty absolute path"* ]]

  TEST_HOME_OVERRIDE=relative
  run_bootstrap
  [ "$status" -eq 1 ]
  [[ $output == *"HOME must be a non-empty absolute path"* ]]
}

@test "Ubuntu 24.04 ARM64 completes through the locked uv path" {
  run_bootstrap

  [ "$status" -eq 0 ]
  assert_log_contains "curl insecure=true https://github.com/shmileee/dotfiles/archive/refs/heads/master.tar.gz"
  assert_log_contains "curl insecure=true https://github.com/astral-sh/uv/releases/download/$expected_uv_version/uv-aarch64-unknown-linux-gnu.tar.gz"
  assert_log_contains " sync --project "
  assert_log_contains "--locked --managed-python"
  assert_log_contains "ansible-galaxy collection install --ignore-certs"
  assert_log_contains "ansible-playbook --inventory 127.0.0.1,"
}

@test "Apple Silicon macOS uses the matching pinned uv artifact under /bin/sh" {
  TEST_OS=Darwin
  TEST_ARCH=arm64

  run_bootstrap /bin/sh

  [ "$status" -eq 0 ]
  assert_log_contains "xcode-select -p"
  assert_log_contains "curl insecure=false"
  assert_log_contains "uv-aarch64-apple-darwin.tar.gz"
  refute_log_contains "--ignore-certs"
}

@test "an existing Ubuntu CA bundle keeps bootstrap TLS verification enabled" {
  printf 'test certificate bundle\n' > "$ca_bundle"

  run_bootstrap

  [ "$status" -eq 0 ]
  assert_log_contains "curl insecure=false"
  refute_log_contains "--ignore-certs"
}

@test "unsupported operating systems releases and architectures stop before sudo or downloads" {
  TEST_OS=FreeBSD
  run_bootstrap
  [ "$status" -eq 1 ]
  [[ $output == *"unsupported operating system"* ]]
  refute_log_contains "sudo"
  refute_log_contains "curl"

  : > "$command_log"
  TEST_OS=Linux
  write_os_release ubuntu 22.04
  run_bootstrap
  [ "$status" -eq 1 ]
  [[ $output == *"only Ubuntu 24.04 ARM64 is supported"* ]]
  refute_log_contains "sudo"
  refute_log_contains "curl"

  : > "$command_log"
  write_os_release ubuntu 24.04
  TEST_ARCH=x86_64
  run_bootstrap
  [ "$status" -eq 1 ]
  [[ $output == *"ARM64 aarch64 is required"* ]]
  refute_log_contains "sudo"
  refute_log_contains "curl"
}

@test "missing Command Line Tools stop macOS before source staging" {
  TEST_OS=Darwin
  TEST_ARCH=arm64
  TEST_XCODE_STATUS=1

  run_bootstrap

  [ "$status" -eq 1 ]
  [[ $output == *'xcode-select --install'* ]]
  refute_log_contains "sudo"
  refute_log_contains "curl"
}

@test "missing sudo is actionable and stops before source staging" {
  rm "$fake_bin/sudo"

  run_bootstrap

  [ "$status" -eq 1 ]
  [[ $output == *"sudo is a required base-system command"* ]]
  refute_log_contains "curl"
}

@test "an occupied streamed target without a receipt exits before all probes" {
  mkdir -p "$test_home/ghq/personalgit/shmileee/dotfiles"

  run_bootstrap

  [ "$status" -eq 1 ]
  [[ $output == *"/d is only for a fresh workstation"* ]]
  [[ $output == *"./scripts/setup.sh"* ]]
  refute_log_contains "uname"
  refute_log_contains "sudo"
  refute_log_contains "curl"
  refute_log_contains "uv "
}

@test "an occupied streamed target with a receipt recommends reconcile and recovery" {
  receipt=$test_home/ghq/personalgit/shmileee/dotfiles/.git/dotfiles-bootstrap-complete
  mkdir -p "$(dirname "$receipt")"
  touch "$receipt"

  run_bootstrap

  [ "$status" -eq 1 ]
  [[ $output == *"mise run reconcile"* ]]
  [[ $output == *"./scripts/setup.sh"* ]]
  refute_log_contains "uname"
  refute_log_contains "sudo"
  refute_log_contains "curl"
}

@test "the checked-out setup command recovers an incomplete persistent clone" {
  target=$test_home/ghq/personalgit/shmileee/dotfiles
  mkdir -p "$target/scripts/common/ansible" "$target/bootstrap"
  cp "$project_root/scripts/setup.sh" "$target/scripts/setup.sh"
  touch "$target/bootstrap/uv.lock"
  touch "$target/scripts/common/ansible/main.yaml"
  touch "$target/scripts/common/ansible/requirements.yml"
  touch "$target/scripts/common/ansible/ansible.cfg"
  TEST_SETUP_PATH=$target/scripts/setup.sh

  run_bootstrap

  [ "$status" -eq 0 ]
  refute_log_contains "dotfiles/archive"
  assert_log_contains "astral-sh/uv"
}

@test "the private workspace is mode 700 and disposable while uv cache survives" {
  mkdir -p "$test_home/.cache/uv"
  touch "$test_home/.cache/uv/keep"

  run_bootstrap

  [ "$status" -eq 0 ]
  assert_log_contains "workspace_mode=700"
  assert_log_contains "uv_cache=unset"
  workspace_path=$(sed -n 's/^workspace=//p' "$command_log" | sed -n '1p')
  [ -n "$workspace_path" ]
  [ ! -e "$workspace_path" ]
  [ -f "$test_home/.cache/uv/keep" ]
}

@test "curl and archive failures preserve status and clean the workspace" {
  TEST_SOURCE_CURL_STATUS=22
  run_bootstrap
  [ "$status" -eq 22 ]
  [[ $output == *"could not download the master source archive"* ]]
  [ -z "$(find "$test_tmp" -mindepth 1 -print -quit)" ]

  TEST_SOURCE_CURL_STATUS=0
  TEST_SOURCE_TAR_STATUS=31
  run_bootstrap
  [ "$status" -eq 31 ]
  [[ $output == *"could not extract"* ]]
  [ -z "$(find "$test_tmp" -mindepth 1 -print -quit)" ]
}

@test "controller validation and provisioning failures remain distinct and clean up" {
  TEST_UV_REPORTED_VERSION=unexpected
  run_bootstrap
  [ "$status" -eq 1 ]
  [[ $output == *"uv version validation failed"* ]]

  TEST_UV_REPORTED_VERSION=$expected_uv_version
  TEST_SYNC_STATUS=41
  run_bootstrap
  [ "$status" -eq 41 ]
  [[ $output == *"bootstrap/uv.lock"* ]]

  TEST_SYNC_STATUS=0
  TEST_GALAXY_STATUS=42
  run_bootstrap
  [ "$status" -eq 42 ]
  [[ $output == *"Ansible Galaxy"* ]]

  TEST_GALAXY_STATUS=0
  TEST_ANSIBLE_STATUS=43
  run_bootstrap
  [ "$status" -eq 43 ]
  [[ $output == *"durable changes"* ]]
  [ -z "$(find "$test_tmp" -mindepth 1 -print -quit)" ]
}

@test "passwordless sudo omits the become prompt flag" {
  TEST_SUDO_STATUS=0

  run_bootstrap

  [ "$status" -eq 0 ]
  assert_log_contains "sudo -k -n true"
  refute_log_contains "--ask-become-pass"
}

@test "a failed passwordless probe delegates one password prompt to Ansible" {
  TEST_SUDO_STATUS=1

  run_bootstrap

  [ "$status" -eq 0 ]
  assert_log_contains "sudo -k -n true"
  assert_log_contains "--ask-become-pass"
  [[ $output == *"Ansible will ask once"* ]]
}

@test "phase messages are ordered and completion is actionable" {
  run_bootstrap

  [ "$status" -eq 0 ]
  [[ $output =~ Staging.*Downloading.*Synchronizing.*Installing.*versions.*Running.*configured ]]
  [[ $output == *"mise run reconcile"* ]]
}

@test "legacy stage arguments are rejected" {
  run_bootstrap "$dash_path" --all

  [ "$status" -eq 2 ]
  [[ $output == *"does not accept stage arguments"* ]]
}

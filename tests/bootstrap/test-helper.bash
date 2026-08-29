setup_bootstrap_test() {
  project_root=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  test_root=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-test.XXXXXX")
  test_home=$test_root/home
  test_tmp=$test_root/tmp
  fake_bin=$test_root/fake-bin
  base_bin=$test_root/base-bin
  command_log=$test_root/commands.log
  setup_copy=$test_root/setup.sh
  os_release=$test_root/os-release
  ca_bundle=$test_root/ca-certificates.crt
  dash_path=$(command -v dash)
  expected_uv_version=$(sed -n 's/^uv_version=//p' "$project_root/scripts/setup.sh")

  mkdir -p "$test_home" "$test_tmp" "$fake_bin" "$base_bin"
  cp "$project_root/scripts/setup.sh" "$setup_copy"
  chmod +x "$setup_copy"
  : > "$command_log"
  write_os_release ubuntu 24.04

  for command_name in cat chmod cp dirname mkdir rm sed stat touch; do
    ln -s "$(command -v "$command_name")" "$base_bin/$command_name"
  done

  make_mock id << 'EOF'
case ${1:-} in
  -u) printf '%s\n' "${TEST_ID_UID:-1000}" ;;
  -un) printf '%s\n' bootstrap-user ;;
  *) exit 64 ;;
esac
EOF

  make_mock uname << 'EOF'
printf 'uname %s\n' "${1:-}" >>"$MOCK_LOG"
case ${1:-} in
  -s) printf '%s\n' "${TEST_OS:-Linux}" ;;
  -m) printf '%s\n' "${TEST_ARCH:-aarch64}" ;;
  *) exit 64 ;;
esac
EOF

  make_mock xcode-select << 'EOF'
printf 'xcode-select %s\n' "$*" >>"$MOCK_LOG"
exit "${TEST_XCODE_STATUS:-0}"
EOF

  make_mock sudo << 'EOF'
printf 'sudo %s\n' "$*" >>"$MOCK_LOG"
exit "${TEST_SUDO_STATUS:-0}"
EOF

  make_mock curl << 'EOF'
output=
url=
insecure=false
while [ "$#" -gt 0 ]; do
  case $1 in
    --output) output=$2; shift 2 ;;
    -*k*) insecure=true; shift ;;
    http*) url=$1; shift ;;
    *) shift ;;
  esac
done
printf 'curl insecure=%s %s\n' "$insecure" "$url" >>"$MOCK_LOG"
case $url in
  *dotfiles/archive*) status=${TEST_SOURCE_CURL_STATUS:-0} ;;
  *astral-sh/uv*) status=${TEST_UV_CURL_STATUS:-0} ;;
  *) status=99 ;;
esac
[ "$status" -eq 0 ] || exit "$status"
: >"$output"
EOF

  make_mock tar << 'EOF'
archive=
destination=
while [ "$#" -gt 0 ]; do
  case $1 in
    -xzf) archive=$2; shift 2 ;;
    -C) destination=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf 'tar %s\n' "$archive" >>"$MOCK_LOG"
case $archive in
  */source.tar.gz)
    [ "${TEST_SOURCE_TAR_STATUS:-0}" -eq 0 ] || exit "$TEST_SOURCE_TAR_STATUS"
    mkdir -p "$destination/bootstrap" "$destination/scripts/common/ansible"
    touch "$destination/bootstrap/uv.lock"
    touch "$destination/scripts/common/ansible/main.yaml"
    touch "$destination/scripts/common/ansible/requirements.yml"
    touch "$destination/scripts/common/ansible/ansible.cfg"
    ;;
  */uv.tar.gz)
    [ "${TEST_UV_TAR_STATUS:-0}" -eq 0 ] || exit "$TEST_UV_TAR_STATUS"
    mkdir -p "$destination/uv-$TEST_UV_ARTIFACT"
    cp "$TEST_FAKE_UV" "$destination/uv-$TEST_UV_ARTIFACT/uv"
    chmod +x "$destination/uv-$TEST_UV_ARTIFACT/uv"
    ;;
  *) exit 98 ;;
esac
EOF
}

teardown_bootstrap_test() {
  rm -rf "$test_root"
}

make_mock() {
  mock_name=$1
  mock_path=$fake_bin/$mock_name
  {
    printf '%s\n' '#!/bin/sh' 'set -eu'
    cat
  } > "$mock_path"
  chmod +x "$mock_path"
}

write_os_release() {
  printf 'ID=%s\nVERSION_ID="%s"\n' "$1" "$2" > "$os_release"
}

run_bootstrap() {
  bootstrap_shell=${1:-$dash_path}
  shift || true
  setup_under_test=${TEST_SETUP_PATH:-$setup_copy}
  case ${TEST_OS:-Linux} in
    Darwin) uv_artifact=aarch64-apple-darwin ;;
    *) uv_artifact=aarch64-unknown-linux-gnu ;;
  esac

  run env \
    HOME="${TEST_HOME_OVERRIDE-$test_home}" \
    TMPDIR="$test_tmp" \
    PATH="$fake_bin:$base_bin" \
    MOCK_LOG="$command_log" \
    DOTFILES_OS_RELEASE_FILE="$os_release" \
    DOTFILES_CA_BUNDLE_FILE="$ca_bundle" \
    TEST_FAKE_UV="$project_root/tests/bootstrap/fake-uv.sh" \
    TEST_UV_ARTIFACT="$uv_artifact" \
    TEST_OS="${TEST_OS:-Linux}" \
    TEST_ARCH="${TEST_ARCH:-aarch64}" \
    TEST_ID_UID="${TEST_ID_UID:-1000}" \
    TEST_XCODE_STATUS="${TEST_XCODE_STATUS:-0}" \
    TEST_SUDO_STATUS="${TEST_SUDO_STATUS:-0}" \
    TEST_SOURCE_CURL_STATUS="${TEST_SOURCE_CURL_STATUS:-0}" \
    TEST_UV_CURL_STATUS="${TEST_UV_CURL_STATUS:-0}" \
    TEST_SOURCE_TAR_STATUS="${TEST_SOURCE_TAR_STATUS:-0}" \
    TEST_UV_TAR_STATUS="${TEST_UV_TAR_STATUS:-0}" \
    TEST_UV_REPORTED_VERSION="${TEST_UV_REPORTED_VERSION:-$expected_uv_version}" \
    TEST_UV_VERSION_STATUS="${TEST_UV_VERSION_STATUS:-0}" \
    TEST_SYNC_STATUS="${TEST_SYNC_STATUS:-0}" \
    TEST_GALAXY_STATUS="${TEST_GALAXY_STATUS:-0}" \
    TEST_ANSIBLE_STATUS="${TEST_ANSIBLE_STATUS:-0}" \
    "$bootstrap_shell" "$setup_under_test" "$@"
}

assert_log_contains() {
  if ! grep -F -- "$1" "$command_log" > /dev/null; then
    printf 'expected command log to contain: %s\n' "$1" >&3
    sed 's/^/  /' "$command_log" >&3
    return 1
  fi
}

refute_log_contains() {
  ! grep -F -- "$1" "$command_log" > /dev/null
}

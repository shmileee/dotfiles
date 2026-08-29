setup_test_environment() {
  project_root=$(CDPATH='' cd -P "${BATS_TEST_DIRNAME}/../.." && pwd)
  test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")
  mock_bin="${test_root}/bin"
  mock_log="${test_root}/commands.log"
  mkdir -p "${mock_bin}"
  : > "${mock_log}"

  export project_root test_root mock_bin mock_log
  export MOCK_LOG="${mock_log}"
  export PATH="${mock_bin}:${PATH}"
}

teardown_test_environment() {
  rm -rf -- "${test_root}"
}

make_mock() {
  local name=$1
  local body=$2
  local path="${mock_bin}/${name}"

  printf '#!/bin/sh\nset -eu\n%s\n' "${body}" > "${path}"
  chmod +x "${path}"
}

assert_log_contains() {
  grep -F -- "$1" "${mock_log}" > /dev/null
}

refute_log_contains() {
  ! grep -F -- "$1" "${mock_log}" > /dev/null
}

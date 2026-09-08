#!/usr/bin/env bats

# Bats supplies status/output; make_mock consumes fake_bin from setup.
# shellcheck disable=SC2034,SC2154
load test-helper.bash

setup() {
  real_mise=$(command -v mise)
  project_root=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  test_home=$BATS_TEST_TMPDIR/home
  personal_root=$test_home/ghq/personalgit
  nested_checkout=$personal_root/shmileee/dotfiles
  fake_bin=$BATS_TEST_TMPDIR/bin
  command_log=$BATS_TEST_TMPDIR/gh-calls
  mkdir -p "$nested_checkout" "$fake_bin" "$test_home/tmp"
  cp "$project_root/config/ghq/personalgit/mise.toml" "$personal_root/mise.toml"

  actions_token="fixture-actions-$BATS_TEST_NUMBER"
  personal_token="fixture-personal-$BATS_TEST_NUMBER"
  fake_token=$personal_token
  make_mock gh << 'EOF'
printf '%s\n' "$@" >> "$MOCK_LOG"
[ "$#" -eq 4 ] && [ "$1" = auth ] && [ "$2" = token ] &&
  [ "$3" = --user ] && [ "$4" = shmileee ] || exit 64
[ "${FAKE_GH_STATUS:-0}" -eq 0 ] || exit "$FAKE_GH_STATUS"
printf '%s\n' "$FAKE_GH_TOKEN"
EOF
}

run_mise() {
  local expected_token=$1
  shift
  # shellcheck disable=SC2016 # Expand variables only in the mise child.
  run env -i \
    HOME="$test_home" \
    TMPDIR="$test_home/tmp" \
    PATH="$fake_bin:/usr/bin:/bin" \
    XDG_CONFIG_HOME="$test_home/.config" \
    XDG_CACHE_HOME="$test_home/.cache" \
    XDG_DATA_HOME="$test_home/.local/share" \
    XDG_STATE_HOME="$test_home/.local/state" \
    MISE_CONFIG_DIR="$test_home/.config/mise" \
    MISE_CACHE_DIR="$test_home/.cache/mise" \
    MISE_DATA_DIR="$test_home/.local/share/mise" \
    MISE_STATE_DIR="$test_home/.local/state/mise" \
    MISE_SYSTEM_CONFIG_DIR="$test_home/system-mise" \
    MISE_GLOBAL_CONFIG_FILE="$test_home/.config/mise/config.toml" \
    MISE_CEILING_PATHS="$test_home" \
    MISE_TRUSTED_CONFIG_PATHS="$personal_root" \
    MOCK_LOG="$command_log" \
    GH_TOKEN="fixture-inherited-$BATS_TEST_NUMBER" \
    GITHUB_TOKEN="$actions_token" \
    FAKE_GH_TOKEN="$fake_token" \
    EXPECTED_TOKEN="$expected_token" \
    "$@" "$real_mise" -C "$nested_checkout" exec -- /bin/sh -eu -c '
      if [ -z "${GH_TOKEN+x}" ]; then
        printf "GH_TOKEN is missing in the mise child\n" >&2
        exit 41
      fi
      if [ "$GH_TOKEN" != "$EXPECTED_TOKEN" ]; then
        printf "GH_TOKEN does not match the expected credential source\n" >&2
        exit 42
      fi
      expected_call=$(printf "%s\n" auth token --user shmileee)
      if [ ! -f "$MOCK_LOG" ] || [ "$(cat "$MOCK_LOG")" != "$expected_call" ]; then
        printf "Expected exactly one personal-account gh lookup\n" >&2
        exit 44
      fi
    '
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output" >&3
    return 1
  fi
}

@test "Actions falls back to GITHUB_TOKEN after the personal gh lookup fails" {
  run_mise "$actions_token" GITHUB_ACTIONS=true FAKE_GH_STATUS=1
}

@test "local GH_TOKEN pins the personal account and reuses the cached lookup" {
  run_mise "$personal_token"
  fake_token="fixture-changed-$BATS_TEST_NUMBER"
  run_mise "$personal_token"
}

@test "GH_TOKEN remains empty when neither credential source exists" {
  run_mise "" env -u GITHUB_TOKEN FAKE_GH_STATUS=1
}

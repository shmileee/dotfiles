# Bats fixtures intentionally expose these values as globals to the test file.
# shellcheck disable=SC2034

setup_fish_test() {
  if ! command -v fish > /dev/null; then
    skip "fish is not installed"
  fi

  project_root=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  function_under_test=$project_root/config/private_dot_config/private_fish/functions/_source_cached_init.fish
  # $version is a fish variable and must reach fish unexpanded.
  # shellcheck disable=SC2016
  fish_version=$(fish --no-config --command 'echo $version')

  test_root=$(mktemp -d "${TMPDIR:-/tmp}/fish-test.XXXXXX")
  cache_home=$test_root/cache
  tool_bin=$test_root/bin
  moved_bin=$test_root/moved-bin
  call_log=$test_root/generator-calls.log
  base_path=$PATH

  mkdir -p "$cache_home" "$tool_bin" "$moved_bin"
  : > "$call_log"
  make_fake_tool "$tool_bin"
}

teardown_fish_test() {
  rm -rf "$test_root"
}

# A stand-in init generator. Every invocation appends to the call log, so a
# cache hit leaves the log untouched while a regeneration grows it. The emitted
# fish code carries the generation number, which lets a test tell whether the
# script it sourced was freshly generated or served from cache.
make_fake_tool() {
  cat > "$1/faketool" << 'EOF'
#!/bin/sh
printf 'faketool\n' >> "$FAKE_TOOL_LOG"
printf 'set -g FAKE_INIT_GENERATION %s\n' "$(wc -l < "$FAKE_TOOL_LOG" | tr -d ' ')"
EOF
  chmod +x "$1/faketool"
}

# Replaces the fake tool with one that fails without emitting anything.
make_failing_tool() {
  cat > "$1/faketool" << 'EOF'
#!/bin/sh
printf 'faketool\n' >> "$FAKE_TOOL_LOG"
exit 1
EOF
  chmod +x "$1/faketool"
}

# Runs the function under test in a bare fish with an isolated cache, config
# and PATH, so neither the caller's environment nor an already deployed copy of
# the function can influence the result.
run_cached_init() {
  bin_dir=${1:-$tool_bin}
  tool_name=${2:-faketool}

  run env \
    HOME="$test_root" \
    XDG_CACHE_HOME="$cache_home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_DATA_HOME="$test_root/data" \
    FAKE_TOOL_LOG="$call_log" \
    PATH="$bin_dir:$base_path" \
    fish --no-config --command "
      source '$function_under_test'
      _source_cached_init $tool_name $tool_name init
      or exit 1
      echo \"generation=\$FAKE_INIT_GENERATION\"
    "
}

generator_calls() {
  wc -l < "$call_log" | tr -d ' '
}

cache_entries() {
  set -- "$cache_home"/fish/faketool-init*.fish
  [ -e "$1" ] || return 0
  printf '%s\n' "$@"
}

count_cache_entries() {
  cache_entries | wc -l | tr -d ' '
}

assert_generator_calls() {
  local expected=$1
  local actual
  actual=$(generator_calls)
  if [ "$actual" != "$expected" ]; then
    printf 'expected %s generator call(s), got %s\n' "$expected" "$actual" >&3
    return 1
  fi
}

assert_cache_entry_count() {
  local expected=$1
  local actual
  actual=$(count_cache_entries)
  if [ "$actual" != "$expected" ]; then
    printf 'expected %s cache entry/entries, got %s:\n' "$expected" "$actual" >&3
    cache_entries | sed 's/^/  /' >&3
    return 1
  fi
}

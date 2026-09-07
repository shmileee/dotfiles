#!/usr/bin/env bats
#
# Behavior tests for _source_cached_init, the fish helper that caches a tool's
# generated shell init script.
#
# The cache is only sound while its key covers every input the generated script
# depends on. A stale script is a silent correctness bug rather than a slow
# startup, so each invalidation dimension gets its own test:
#
#   * the resolved binary path (direnv bakes its own absolute path into the hook
#     it emits, and a move cannot be observed through an mtime check)
#   * the running fish version (zoxide's init copies fish's internal `cd`)
#   * the binary mtime (in-place upgrades)

setup() {
  load test-helper
  setup_fish_test
}

teardown() {
  teardown_fish_test
}

@test "cold start generates the cache and sources it" {
  run_cached_init

  [ "$status" -eq 0 ]
  [[ $output == *"generation=1"* ]]
  assert_generator_calls 1
  assert_cache_entry_count 1
}

@test "warm start reuses the cache without invoking the generator" {
  run_cached_init
  [ "$status" -eq 0 ]

  run_cached_init

  [ "$status" -eq 0 ]
  [[ $output == *"generation=1"* ]]
  assert_generator_calls 1
  assert_cache_entry_count 1
}

@test "relocating the binary invalidates the cache even when its mtime is older" {
  run_cached_init
  [ "$status" -eq 0 ]

  # Identical content at a different path, deliberately older than the cache so
  # that the mtime guard cannot be what triggers the regeneration.
  make_fake_tool "$moved_bin"
  touch -t 200001010000 "$moved_bin/faketool"

  run_cached_init "$moved_bin"

  [ "$status" -eq 0 ]
  [[ $output == *"generation=2"* ]]
  assert_generator_calls 2
  assert_cache_entry_count 1

  local expected_key
  expected_key=$(printf '%s' "$moved_bin/faketool" | tr -c 'A-Za-z0-9._-' '_')
  [[ $(cache_entries) == *"$expected_key"* ]]
}

@test "the cache key includes the running fish version" {
  run_cached_init
  [ "$status" -eq 0 ]

  # A fish upgrade cannot be simulated in-process because $version is
  # read-only, so assert the version reaches the key. The relocation test above
  # already establishes that a changed key forces a regeneration.
  [[ $(basename "$(cache_entries)") == *"-$fish_version.fish" ]]
}

@test "a newer binary invalidates the cache" {
  run_cached_init
  [ "$status" -eq 0 ]

  # Age the cache instead of touching the binary, so the comparison is decided
  # by mtime order rather than by filesystem timestamp granularity.
  touch -t 200001010000 "$(cache_entries)"

  run_cached_init

  [ "$status" -eq 0 ]
  [[ $output == *"generation=2"* ]]
  assert_generator_calls 2
  assert_cache_entry_count 1
}

@test "a failing generator reports failure and preserves the previous cache" {
  run_cached_init
  [ "$status" -eq 0 ]

  local cache_path checksum_before
  cache_path=$(cache_entries)
  checksum_before=$(cksum < "$cache_path")

  make_failing_tool "$tool_bin"
  touch -t 200001010000 "$cache_path"

  run_cached_init

  [ "$status" -ne 0 ]
  [ "$(cksum < "$cache_path")" = "$checksum_before" ]
  assert_cache_entry_count 1

  # A half-written cache must never be left behind.
  run bash -c 'ls "$1"/fish/*.new 2>/dev/null | wc -l | tr -d " "' _ "$cache_home"
  [ "$output" = "0" ]
}

@test "regeneration removes stale variants including the legacy unkeyed cache" {
  run_cached_init
  [ "$status" -eq 0 ]

  local cache_path
  cache_path=$(cache_entries)
  touch "$cache_home/fish/faketool-init.fish"
  assert_cache_entry_count 2

  touch -t 200001010000 "$cache_path"
  run_cached_init

  [ "$status" -eq 0 ]
  assert_cache_entry_count 1
  [ ! -e "$cache_home/fish/faketool-init.fish" ]
}

@test "a missing tool is a silent no-op" {
  run_cached_init "$tool_bin" definitely-not-installed

  [ "$status" -eq 0 ]
  assert_generator_calls 0
  assert_cache_entry_count 0
}

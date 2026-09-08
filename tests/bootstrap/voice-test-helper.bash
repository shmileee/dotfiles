# Bats fixtures intentionally expose these values as globals to the test file.
# shellcheck disable=SC2034

setup_voice_test() {
  project_root=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  voice_setup=$project_root/bootstrap/voice-setup.sh
  test_root=$(mktemp -d "${TMPDIR:-/tmp}/voice-test.XXXXXX")
  test_home=$test_root/home
  fake_bin=$test_root/fake-bin
  base_bin=$test_root/base-bin
  command_log=$test_root/commands.log
  agent_dir=$test_root/agents
  dash_path=$(command -v dash)

  # Read back out of the script so assertions cannot drift from the real values.
  expected_model_file=$(sed -n 's/^whisper_model_file=//p' "$voice_setup")
  expected_model_revision=$(sed -n 's/^whisper_model_revision=//p' "$voice_setup")
  expected_model_sha256=$(sed -n 's/^whisper_model_sha256=//p' "$voice_setup")
  expected_base_model=$(sed -n 's/^ollama_base_model=//p' "$voice_setup")
  expected_voice_model=$(sed -n 's/^ollama_voice_model=//p' "$voice_setup")
  whisper_agent=$(sed -n 's/^whisper_agent=//p' "$voice_setup")
  ollama_agent=$(sed -n 's/^ollama_agent=//p' "$voice_setup")

  model_dir=$test_home/.local/share/whisper-cpp
  model_path=$model_dir/$expected_model_file
  modelfile=$test_home/.config/ollama/voice-normalize.Modelfile
  whisper_plist=$test_home/Library/LaunchAgents/$whisper_agent.plist
  ollama_plist=$test_home/Library/LaunchAgents/$ollama_agent.plist

  # Not inlined below: a literal '}' inside ${var-default} needs escaping, and
  # getting that wrong silently changes the fixture.
  default_health_body='{"status":"ok"}'
  default_completion_body='{"choices":[{"message":{"content":"ping"}}]}'

  mkdir -p "$test_home" "$fake_bin" "$base_bin" "$agent_dir" \
    "$(dirname "$modelfile")" "$(dirname "$whisper_plist")"
  : > "$command_log"

  printf 'FROM %s\n' "$expected_base_model" > "$modelfile"
  printf 'managed plist\n' > "$whisper_plist"
  printf 'managed plist\n' > "$ollama_plist"

  # Tests move these with set_agent_state.
  set_agent_state "$whisper_agent" true running 1234
  set_agent_state "$ollama_agent" true running 2234

  for command_name in cat cut grep mkdir mv rm sed sleep; do
    ln -s "$(command -v "$command_name")" "$base_bin/$command_name"
  done

  make_voice_mock uname << 'EOF'
printf 'uname %s\n' "${1:-}" >>"$MOCK_LOG"
case ${1:-} in
  -s) printf '%s\n' "$TEST_OS" ;;
  *) exit 64 ;;
esac
EOF

  make_voice_mock id << 'EOF'
case ${1:-} in
  -u) printf '501\n' ;;
  *) exit 64 ;;
esac
EOF

  # Present only so `command -v` resolves it; the setup script never runs it.
  make_voice_mock whisper-server << 'EOF'
printf 'whisper-server %s\n' "$*" >>"$MOCK_LOG"
EOF

  make_voice_mock nc << 'EOF'
printf 'nc %s\n' "$*" >>"$MOCK_LOG"
exit "$TEST_NC_STATUS"
EOF

  make_voice_mock lsof << 'EOF'
printf 'lsof %s\n' "$*" >>"$MOCK_LOG"
exit "$TEST_LSOF_STATUS"
EOF

  make_voice_mock shasum << 'EOF'
printf 'shasum %s\n' "$*" >>"$MOCK_LOG"
printf '%s  %s\n' "$TEST_MODEL_DIGEST" "$3"
EOF

  make_voice_mock ollama << 'EOF'
printf 'ollama %s\n' "$*" >>"$MOCK_LOG"
case ${1:-} in
  list)
    printf 'NAME ID SIZE MODIFIED\n'
    printf '%s\n' "$TEST_OLLAMA_LIST"
    ;;
  pull) ;;
  create)
    printf 'gathering model components\n'
    printf 'writing manifest\n' >&2
    exit "$TEST_OLLAMA_CREATE_STATUS"
    ;;
  *) exit 64 ;;
esac
EOF

  make_voice_mock curl << 'EOF'
output=
url=
while [ "$#" -gt 0 ]; do
  case $1 in
    -o|-H|-d|--max-time) [ "$1" = -o ] && output=$2; shift 2 ;;
    http*) url=$1; shift ;;
    *) shift ;;
  esac
done
printf 'curl %s\n' "$url" >>"$MOCK_LOG"
case $url in
  *huggingface.co*)
    [ "$TEST_MODEL_CURL_STATUS" -eq 0 ] || exit "$TEST_MODEL_CURL_STATUS"
    printf 'downloaded model bytes\n' >"$output"
    ;;
  */health) printf '%s' "$TEST_HEALTH_BODY" ;;
  */chat/completions)
    if [ "$TEST_COMPLETION_STATUS" -ne 0 ]; then
      printf 'curl: (%s) could not reach the endpoint\n' "$TEST_COMPLETION_STATUS" >&2
      exit "$TEST_COMPLETION_STATUS"
    fi
    printf '%s' "$TEST_COMPLETION_BODY"
    ;;
  *) exit 99 ;;
esac
EOF

  # Per-label state on disk, so `print` reports what `bootstrap` and `kickstart`
  # actually did.
  make_voice_mock launchctl << 'EOF'
printf 'launchctl %s\n' "$*" >>"$MOCK_LOG"
action=${1:-}
shift || true
case $action in
  print)
    label=${1##*/}
    [ "$(cat "$TEST_AGENT_DIR/$label.loaded" 2>/dev/null || printf false)" = true ] || exit 113
    printf '%s = {\n' "$label"
    printf '\tstate = %s\n' "$(cat "$TEST_AGENT_DIR/$label.state")"
    printf '\tpid = %s\n' "$(cat "$TEST_AGENT_DIR/$label.pid")"
    printf '}\n'
    ;;
  bootstrap)
    label=${2##*/}
    label=${label%.plist}
    printf 'true\n' >"$TEST_AGENT_DIR/$label.loaded"
    printf 'running\n' >"$TEST_AGENT_DIR/$label.state"
    printf '9000\n' >"$TEST_AGENT_DIR/$label.pid"
    ;;
  kickstart)
    [ "${1:-}" != -k ] || shift
    label=${1##*/}
    if [ "$TEST_KICKSTART_STATE" != unchanged ]; then
      printf '%s\n' "$TEST_KICKSTART_STATE" >"$TEST_AGENT_DIR/$label.state"
      printf '%s\n' "$(($(cat "$TEST_AGENT_DIR/$label.pid") + 1))" >"$TEST_AGENT_DIR/$label.pid"
    fi
    ;;
  *) exit 64 ;;
esac
EOF
}

teardown_voice_test() {
  rm -rf "$test_root"
}

make_voice_mock() {
  mock_name=$1
  mock_path=$fake_bin/$mock_name
  {
    printf '%s\n' '#!/bin/sh' 'set -eu'
    cat
  } > "$mock_path"
  chmod +x "$mock_path"
}

set_agent_state() {
  printf '%s\n' "$2" > "$agent_dir/$1.loaded"
  printf '%s\n' "$3" > "$agent_dir/$1.state"
  printf '%s\n' "$4" > "$agent_dir/$1.pid"
}

agent_field() {
  cat "$agent_dir/$1.$2"
}

install_verified_model() {
  mkdir -p "$model_dir"
  printf 'existing model bytes\n' > "$model_path"
}

run_voice_setup() {
  voice_shell=${1:-$dash_path}

  run env \
    HOME="$test_home" \
    PATH="$fake_bin:$base_bin" \
    MOCK_LOG="$command_log" \
    TEST_AGENT_DIR="$agent_dir" \
    TEST_OS="${TEST_OS:-Darwin}" \
    TEST_NC_STATUS="${TEST_NC_STATUS:-0}" \
    TEST_LSOF_STATUS="${TEST_LSOF_STATUS:-1}" \
    TEST_MODEL_DIGEST="${TEST_MODEL_DIGEST:-$expected_model_sha256}" \
    TEST_MODEL_CURL_STATUS="${TEST_MODEL_CURL_STATUS:-0}" \
    TEST_OLLAMA_LIST="${TEST_OLLAMA_LIST-$expected_base_model}" \
    TEST_OLLAMA_CREATE_STATUS="${TEST_OLLAMA_CREATE_STATUS:-0}" \
    TEST_KICKSTART_STATE="${TEST_KICKSTART_STATE:-running}" \
    TEST_HEALTH_BODY="${TEST_HEALTH_BODY-$default_health_body}" \
    TEST_COMPLETION_STATUS="${TEST_COMPLETION_STATUS:-0}" \
    TEST_COMPLETION_BODY="${TEST_COMPLETION_BODY-$default_completion_body}" \
    DOTFILES_VOICE_POLL_DELAY=0 \
    DOTFILES_VOICE_OLLAMA_ATTEMPTS="${DOTFILES_VOICE_OLLAMA_ATTEMPTS:-3}" \
    DOTFILES_VOICE_HEALTH_ATTEMPTS="${DOTFILES_VOICE_HEALTH_ATTEMPTS:-3}" \
    "$voice_shell" "$voice_setup"
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

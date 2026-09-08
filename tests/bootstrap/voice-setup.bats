#!/usr/bin/env bats

# Bats exposes setup fixtures as globals and passes TEST_* controls to helpers.
# shellcheck disable=SC2034,SC2154

load voice-test-helper.bash

setup() {
  setup_voice_test
}

teardown() {
  teardown_voice_test
}

@test "the voice provisioner parses under Dash and /bin/sh" {
  run "$dash_path" -n "$voice_setup"
  [ "$status" -eq 0 ]

  run /bin/sh -n "$voice_setup"
  [ "$status" -eq 0 ]
}

@test "the pinned model identity is internally consistent" {
  [ "$expected_model_file" = ggml-large-v3-turbo-q5_0.bin ]
  [ "${#expected_model_sha256}" -eq 64 ]
  [ "${#expected_model_revision}" -eq 40 ]
  # A thinking checkpoint would paste its reasoning into the prompt box.
  [[ $expected_base_model == *-instruct-* ]]
}

@test "non-macOS hosts are refused before any mutation" {
  TEST_OS=Linux

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"supports macOS only"* ]]
  refute_log_contains "ollama"
  refute_log_contains "curl"
  refute_log_contains "launchctl"
}

@test "a missing dependency names itself and points at reconcile" {
  rm "$fake_bin/ollama"

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"missing ollama"* ]]
  [[ $output == *"mise run reconcile"* ]]
  refute_log_contains "launchctl"
  refute_log_contains "curl"
}

@test "every unapplied chezmoi input is reported instead of provisioned around" {
  for managed in "$modelfile" "$whisper_plist" "$ollama_plist"; do
    moved=$managed.moved
    mv "$managed" "$moved"

    run_voice_setup

    [ "$status" -eq 1 ]
    [[ $output == *"${managed##*/}"* ]]
    [[ $output == *"chezmoi apply"* ]]
    refute_log_contains "curl"

    mv "$moved" "$managed"
  done
}

@test "a verified model on disk is not downloaded again" {
  install_verified_model

  run_voice_setup

  [ "$status" -eq 0 ]
  [[ $output == *"present and verified"* ]]
  refute_log_contains "huggingface.co"
}

@test "a missing model is fetched from the pinned revision and published atomically" {
  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "huggingface.co/ggerganov/whisper.cpp/resolve/$expected_model_revision/$expected_model_file"
  [ -f "$model_path" ]
  [ ! -e "$model_path.partial" ]
  [[ $output == *"verified"* ]]
}

@test "a corrupt download is discarded rather than published" {
  TEST_MODEL_DIGEST=0000000000000000000000000000000000000000000000000000000000000000

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"checksum mismatch"* ]]
  [[ $output == *"$expected_model_sha256"* ]]
  [ ! -e "$model_path" ]
  [ ! -e "$model_path.partial" ]
  refute_log_contains "ollama create"
}

@test "a failed model download stops before either service is touched" {
  TEST_MODEL_CURL_STATUS=22

  run_voice_setup

  [ "$status" -ne 0 ]
  refute_log_contains "launchctl bootstrap"
  refute_log_contains "launchctl kickstart"
  refute_log_contains "ollama create"
}

@test "an unloaded ollama agent is bootstrapped from the managed plist" {
  install_verified_model
  set_agent_state "$ollama_agent" false 'not running' 0

  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "launchctl bootstrap gui/501 $ollama_plist"
  [ "$(agent_field "$ollama_agent" loaded)" = true ]
}

@test "a loaded but stopped ollama agent is started without killing anything" {
  install_verified_model
  set_agent_state "$ollama_agent" true waiting 2234

  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "launchctl kickstart gui/501/$ollama_agent"
  refute_log_contains "kickstart -k gui/501/$ollama_agent"
  [[ $output == *"started"* ]]
}

@test "an already running ollama agent is not restarted" {
  install_verified_model

  run_voice_setup

  [ "$status" -eq 0 ]
  [[ $output == *"already running"* ]]
  # Restarting would drop the loaded model: `ollama create` registers the
  # derived model with the server that is already up.
  refute_log_contains "kickstart gui/501/$ollama_agent"
  refute_log_contains "kickstart -k gui/501/$ollama_agent"
  [ "$(agent_field "$ollama_agent" pid)" -eq 2234 ]
}

@test "ollama that never listens fails with the port and its log" {
  install_verified_model
  TEST_NC_STATUS=1

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"ollama did not start on port 11434"* ]]
  [[ $output == *"Logs/ollama.log"* ]]
  refute_log_contains "ollama create"
}

@test "an ollama endpoint answering beside a stopped agent is still a failure" {
  install_verified_model
  set_agent_state "$ollama_agent" true waiting 2234
  TEST_KICKSTART_STATE=waiting

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"ollama answered but its LaunchAgent is not running"* ]]
}

@test "an absent base model is pulled before the derived model is built" {
  install_verified_model
  TEST_OLLAMA_LIST=

  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "ollama pull $expected_base_model"
  assert_log_contains "ollama create $expected_voice_model"
}

@test "a present base model is not pulled again but is always rebuilt" {
  install_verified_model

  run_voice_setup

  [ "$status" -eq 0 ]
  [[ $output == *"base model present"* ]]
  refute_log_contains "ollama pull"
  assert_log_contains "ollama create $expected_voice_model"
}

@test "a failed ollama create surfaces the tool's own output" {
  install_verified_model
  TEST_OLLAMA_CREATE_STATUS=1

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"ollama create failed"* ]]
  [[ $output == *"writing manifest"* ]]
  refute_log_contains "kickstart -k"
}

@test "an unloaded transcription agent is bootstrapped rather than kickstarted" {
  install_verified_model
  set_agent_state "$whisper_agent" false 'not running' 0

  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "launchctl bootstrap gui/501 $whisper_plist"
  refute_log_contains "kickstart -k"
  [[ $output == *"loaded"* ]]
}

@test "a loaded transcription agent is replaced rather than left alone" {
  install_verified_model

  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "launchctl kickstart -k gui/501/$whisper_agent"
  [[ $output == *"restarted"* ]]
  # `kickstart -k` kills the old process first, so the vocabulary is re-read.
  refute_log_contains "kickstart gui/501/$whisper_agent"
}


@test "an unhealthy service with a foreign listener names the port conflict" {
  install_verified_model
  TEST_HEALTH_BODY=nothing-listening-here
  TEST_LSOF_STATUS=0

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"port 8081 is held by another process"* ]]
  assert_log_contains "lsof -nP -iTCP:8081 -sTCP:LISTEN"
}

@test "an unhealthy service on a free port points at the service log" {
  install_verified_model
  TEST_HEALTH_BODY=nothing-listening-here
  TEST_LSOF_STATUS=1

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"whisper-server did not start"* ]]
  [[ $output == *"whisper-voice-server.log"* ]]
}

@test "a healthy endpoint beside a stopped transcription agent is still a failure" {
  install_verified_model
  # A started replacement that launchd still reports as stopped: what the
  # wrapper's deliberate exit 0 looks like from here.
  TEST_KICKSTART_STATE=waiting

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"whisper-server answered but its LaunchAgent is not running"* ]]
}

@test "a normalization endpoint that refuses the request fails loudly" {
  install_verified_model
  TEST_COMPLETION_STATUS=7

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"did not answer a chat completion"* ]]
  [[ $output == *"could not reach the endpoint"* ]]
}

@test "a reasoning block in the completion is rejected" {
  install_verified_model
  TEST_COMPLETION_BODY='{"choices":[{"message":{"content":"<think>hmm</think>ping"}}]}'

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"emitted a reasoning block"* ]]
  [[ $output == *"non-thinking base model"* ]]
}

@test "a response without completion choices is rejected" {
  install_verified_model
  TEST_COMPLETION_BODY='{"error":{"message":"model not found"}}'

  run_voice_setup

  [ "$status" -eq 1 ]
  [[ $output == *"unexpected completion response"* ]]
  [[ $output == *"model not found"* ]]
}

@test "the completion probe uses the derived model on the plugin's endpoint" {
  install_verified_model

  run_voice_setup

  [ "$status" -eq 0 ]
  assert_log_contains "curl http://127.0.0.1:11434/v1/chat/completions"
}

@test "phase messages are ordered and completion is reported under both shells" {
  install_verified_model

  for shell_under_test in "$dash_path" /bin/sh; do
    : > "$command_log"
    set_agent_state "$whisper_agent" true running 1234
    run_voice_setup "$shell_under_test"

    [ "$status" -eq 0 ]
    [[ $output =~ transcription\ model.*ollama\ service.*normalization\ model.*transcription\ service.*normalization\ endpoint ]]
    [[ $output == *"serving on 127.0.0.1:11434"* ]]
    [[ $output == *"healthy on 127.0.0.1:8081"* ]]
    [[ $output == *"answering chat completions"* ]]
    [[ $output == *"voice stack ready"* ]]
  done
}

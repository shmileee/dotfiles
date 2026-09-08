#!/bin/sh
# Provision the local voice dictation stack for the opencode-voice plugin.
#
#   mise run voice:setup

set -eu

# Frozen by hand. Renovate can bump neither: the whisper checksum has to be
# re-measured alongside the revision, and ollama tags are not a datasource it
# knows. The instruct-2507 suffix is load bearing -- see the Modelfile.
whisper_model_file=ggml-large-v3-turbo-q5_0.bin
whisper_model_revision=5359861c739e955e79d9a303bcbc70fb988958b1
whisper_model_sha256=394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2
ollama_base_model=qwen3:4b-instruct-2507-q4_K_M
ollama_voice_model=voice-normalize

whisper_agent=com.shmileee.whisper-voice-server
ollama_agent=com.shmileee.ollama
whisper_port=8081
ollama_port=11434

model_dir="${HOME}/.local/share/whisper-cpp"
model_path="${model_dir}/${whisper_model_file}"
modelfile="${HOME}/.config/ollama/voice-normalize.Modelfile"
whisper_plist="${HOME}/Library/LaunchAgents/${whisper_agent}.plist"
ollama_plist="${HOME}/Library/LaunchAgents/${ollama_agent}.plist"
whisper_log="${HOME}/Library/Logs/whisper-voice-server.log"
ollama_log="${HOME}/Library/Logs/ollama.log"
domain="gui/$(id -u)"

poll_delay="${DOTFILES_VOICE_POLL_DELAY:-1}"
ollama_attempts="${DOTFILES_VOICE_OLLAMA_ATTEMPTS:-60}"
health_attempts="${DOTFILES_VOICE_HEALTH_ATTEMPTS:-120}"
completion_timeout=120

phase() {
  printf '==> %s\n' "$1"
}

step() {
  printf '    %s\n' "$1"
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

wait_for() {
  wait_predicate=$1
  wait_attempts=$2
  wait_attempt=0
  while [ "$wait_attempt" -lt "$wait_attempts" ]; do
    if "$wait_predicate"; then
      return 0
    fi
    sleep "$poll_delay"
    wait_attempt=$((wait_attempt + 1))
  done
  return 1
}

digest() {
  shasum -a 256 "$1" | cut -d ' ' -f 1
}

check_prerequisites() {
  [ "$(uname -s)" = "Darwin" ] || fail 'voice:setup supports macOS only'

  # whisper-server is checked on the LaunchAgent's behalf; this script never
  # runs it.
  for binary in ollama whisper-server; do
    command -v "$binary" > /dev/null 2>&1 \
      || fail "missing ${binary}: run 'mise run reconcile' first"
  done

  for managed in "$modelfile" "$whisper_plist" "$ollama_plist"; do
    [ -r "$managed" ] || fail "missing ${managed}: run 'chezmoi apply' first"
  done
}

sync_whisper_model() {
  phase 'whisper transcription model'
  if [ -r "$model_path" ] && [ "$(digest "$model_path")" = "$whisper_model_sha256" ]; then
    step 'present and verified'
    return 0
  fi

  step "downloading ${whisper_model_file} (547 MB)"
  mkdir -p "$model_dir"
  # Pinned revision, not main: the upstream branch is mutable.
  curl -fL --progress-bar \
    -o "${model_path}.partial" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/${whisper_model_revision}/${whisper_model_file}"

  actual="$(digest "${model_path}.partial")"
  if [ "$actual" != "$whisper_model_sha256" ]; then
    rm -f "${model_path}.partial"
    fail "checksum mismatch: expected ${whisper_model_sha256}, got ${actual}"
  fi
  # A corrupt model degrades transcription rather than failing, so it must not
  # appear under the real name until verified.
  mv "${model_path}.partial" "$model_path"
  step 'verified'
}

agent_loaded() {
  launchctl print "${domain}/$1" > /dev/null 2>&1
}

# `grep -q` closes the pipe on its first match, which would fail this under
# `set -o pipefail`. That is why this script does not set it.
agent_running() {
  launchctl print "${domain}/$1" 2> /dev/null \
    | grep -qE '^[[:space:]]+state = running'
}

# "keep" leaves an already-serving process alone: restarting ollama drops its
# loaded models, and `ollama create` registers the derived model with the live
# server anyway.
start_agent() {
  agent_label=$1
  agent_plist=$2
  agent_mode=$3

  if ! agent_loaded "$agent_label"; then
    launchctl bootstrap "$domain" "$agent_plist"
    step 'loaded'
  elif [ "$agent_mode" = force ]; then
    launchctl kickstart -k "${domain}/${agent_label}"
    step 'restarted'
  elif agent_running "$agent_label"; then
    step 'already running'
  else
    launchctl kickstart "${domain}/${agent_label}"
    step 'started'
  fi
}

ollama_listening() {
  nc -z 127.0.0.1 "$ollama_port" 2> /dev/null
}

start_ollama() {
  phase 'ollama service'
  start_agent "$ollama_agent" "$ollama_plist" keep
  wait_for ollama_listening "$ollama_attempts" \
    || fail "ollama did not start on port ${ollama_port}; see ${ollama_log}"

  # An open port is not proof the managed agent owns it.
  agent_running "$ollama_agent" \
    || fail "ollama answered but its LaunchAgent is not running; see ${ollama_log}"
  step "serving on 127.0.0.1:${ollama_port}"
}

build_normalization_model() {
  phase 'normalization model'
  installed="$(ollama list)"
  case $installed in
    *"$ollama_base_model"*)
      step 'base model present'
      ;;
    *)
      step "pulling ${ollama_base_model} (2.5 GB)"
      ollama pull "$ollama_base_model"
      ;;
  esac

  # Rebuilt every run: a manifest over existing layers is free, and it is what
  # picks up an edited Modelfile. Progress is raw terminal escapes on stderr.
  if ! create_log="$(ollama create "$ollama_voice_model" -f "$modelfile" 2>&1)"; then
    printf '%s\n' "$create_log" >&2
    fail 'ollama create failed'
  fi
  step "built ${ollama_voice_model}"
}

whisper_healthy() {
  [ "$(curl -s --max-time 2 "http://127.0.0.1:${whisper_port}/health")" = '{"status":"ok"}' ]
}

start_whisper() {
  phase 'transcription service'
  start_agent "$whisper_agent" "$whisper_plist" force

  if ! wait_for whisper_healthy "$health_attempts"; then
    if lsof -nP -iTCP:"${whisper_port}" -sTCP:LISTEN > /dev/null 2>&1; then
      fail "port ${whisper_port} is held by another process; stop it and rerun"
    fi
    fail "whisper-server did not start; see ${whisper_log}"
  fi

  # Nor is /health: another whisper-server on 8081 would answer it.
  agent_running "$whisper_agent" \
    || fail "whisper-server answered but its LaunchAgent is not running; see ${whisper_log}"
  step "healthy on 127.0.0.1:${whisper_port}"
}

verify_normalization_model() {
  phase 'normalization endpoint'
  # `ollama create` writes a manifest; it does not prove the model loads.
  payload="$(printf \
    '{"model":"%s","max_tokens":16,"messages":[{"role":"user","content":"ping"}]}' \
    "$ollama_voice_model")"

  if ! response="$(curl -fsS --max-time "$completion_timeout" \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "http://127.0.0.1:${ollama_port}/v1/chat/completions" 2>&1)"; then
    printf '%s\n' "$response" >&2
    fail "${ollama_voice_model} did not answer a chat completion"
  fi

  case $response in
    # Before the success case: a reasoning response contains both.
    *'<think>'*)
      fail "${ollama_voice_model} emitted a reasoning block; use a non-thinking base model"
      ;;
    *'"choices"'*)
      step 'answering chat completions'
      ;;
    *)
      fail "unexpected completion response: ${response}"
      ;;
  esac
}

check_prerequisites
sync_whisper_model
start_ollama
build_normalization_model
start_whisper
verify_normalization_model
printf '\nvoice stack ready\n'

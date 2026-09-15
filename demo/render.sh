#!/usr/bin/env bash
# Render the README demo GIF.
#
#   ./render.sh                    provision, record, optimise, tear down
#   ./render.sh --keep             leave the sandbox up afterwards
#   ./render.sh --reuse            skip provisioning, use the existing sandbox
#   ./render.sh --scene nvim       record one scene only, to demo/scene-nvim.gif
#   ./render.sh --reuse --scene k9s --keep     the usual iteration loop
#
# Scene names are the basenames in demo/scenes.

set -euo pipefail

DEMO_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly DEMO_DIR
readonly SCENE_DIR="${DEMO_DIR}/scenes"
readonly BUILD_TAPE="${DEMO_DIR}/.render.tape"

KEEP=0
REUSE=0
SCENE=''

log() { printf '\033[38;2;130;170;255m==>\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[38;2;255;117;127mERROR\033[0m %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --reuse) REUSE=1 ;;
    --scene)
      [[ $# -ge 2 ]] || die '--scene needs a name'
      SCENE="$2"
      shift
      ;;
    -h | --help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

if [[ -n "$SCENE" && ! -f "${SCENE_DIR}/${SCENE}.tape" ]]; then
  die "no such scene: ${SCENE} (have: $(
    cd "$SCENE_DIR" && printf '%s ' *.tape
  ))"
fi

run() {
  if command -v mise > /dev/null 2>&1; then
    mise exec -- "$@"
  else
    "$@"
  fi
}

# Probing with --version is unreliable (ffmpeg only accepts -version), so ask
# for the path instead. mise-managed tools are not on a non-interactive PATH,
# hence the second branch.
have() {
  command -v "$1" > /dev/null 2>&1 && return 0
  command -v mise > /dev/null 2>&1 && mise which "$1" > /dev/null 2>&1
}

for tool in vhs ttyd ffmpeg; do
  have "$tool" || die "${tool} not found"
done

cleanup() {
  rm -f "$BUILD_TAPE"
  if [[ $KEEP -eq 0 ]]; then
    "${DEMO_DIR}/sandbox.sh" down
  else
    log "sandbox left up; re-run with --reuse, or ./sandbox.sh down to remove"
  fi
}
trap cleanup EXIT

if [[ $REUSE -eq 0 ]]; then
  "${DEMO_DIR}/sandbox.sh" up
else
  log 'reusing existing sandbox'
  "${DEMO_DIR}/sandbox.sh" check
fi

# The tape reads these instead of hardcoding paths, which keeps it portable and
# keeps every tmux call in it pinned to the sandbox socket.
while IFS='=' read -r key value; do
  export "${key}=${value}"
done < <("${DEMO_DIR}/sandbox.sh" env)

# Every render starts from a clean tmux state. A session left behind by an
# earlier --keep run makes the tape's `new-session -s dotfiles` fail as a
# duplicate, and the rest of the keystrokes then land in the outer shell, which
# records a wall of "command not found" instead of a demo. Targets the sandbox
# socket only.
if [[ -S "$DEMO_TMUX_SOCKET" ]]; then
  log 'clearing the tmux server left by a previous render'
  run tmux -S "$DEMO_TMUX_SOCKET" kill-server 2> /dev/null || true
fi

# Applications that persist state into the sandbox are put back to their
# post-provision condition, so this render records the same thing the last one
# did rather than resuming where it left off.
"${DEMO_DIR}/sandbox.sh" reset

output='dotfiles.gif'
tape='demo.tape'

# One scene: reuse the hero tape's settings block and swap the scene list, so
# there is only ever one place where font, size and theme are defined.
if [[ -n "$SCENE" ]]; then
  output="scene-${SCENE}.gif"
  tape='.render.tape'
  sed -E \
    -e "s|^Output .*|Output ${output}|" \
    -e '\|^Source scenes/.*\.tape$|d' \
    "${DEMO_DIR}/demo.tape" > "$BUILD_TAPE"
  printf 'Source scenes/%s.tape\n' "$SCENE" >> "$BUILD_TAPE"
fi

log "recording ${output}"

# VHS renders in its own ttyd terminal, but it inherits this process'
# environment, and $TMUX is set whenever render.sh is started from inside tmux.
# A pane shell that believes it is already inside tmux refuses to attach, so the
# variable is dropped for the child only. This is not a nesting bypass: the
# session being attached to lives on the sandbox socket that the tape passes
# explicitly, on a different server from the one running this shell.
(
  cd "$DEMO_DIR"
  if command -v mise > /dev/null 2>&1; then
    env -u TMUX -u TMUX_PANE mise exec -- vhs "$tape"
  else
    env -u TMUX -u TMUX_PANE vhs "$tape"
  fi
)

[[ -f "${DEMO_DIR}/${output}" ]] || die "vhs produced no ${output}"

before=$(wc -c < "${DEMO_DIR}/${output}")

# VHS already runs the frames through ffmpeg's palette filters; gifsicle mostly
# wins on inter-frame optimisation, which matters here because a terminal only
# changes a few cells per frame.
if have gifsicle; then
  log 'optimising with gifsicle'
  run gifsicle -O3 --lossy=40 --careful \
    "${DEMO_DIR}/${output}" -o "${DEMO_DIR}/${output}.opt"
  mv "${DEMO_DIR}/${output}.opt" "${DEMO_DIR}/${output}"
else
  log 'gifsicle not found, skipping optimisation'
fi

after=$(wc -c < "${DEMO_DIR}/${output}")
log "$(printf '%s: %.1f MiB -> %.1f MiB' \
  "$output" "$(bc -l <<< "$before/1048576")" "$(bc -l <<< "$after/1048576")")"

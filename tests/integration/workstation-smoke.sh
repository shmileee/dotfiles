#!/usr/bin/env bash

set -euoE pipefail

image="${1:?Usage: $0 IMAGE}"

# The image is the artifact under test, so the assertions run inside it,
# against the checkout Ansible left behind: tests/provisioned holds them for
# both this image and a provisioned macOS runner.
docker run --rm --entrypoint /bin/bash "$image" -lc '
  set -euo pipefail
  receipt="$(find "$HOME/ghq/personalgit" -type f -path "*/.git/dotfiles-bootstrap-complete" -print -quit)"
  test -n "$receipt"
  cd "${receipt%/.git/dotfiles-bootstrap-complete}"
  mise run test:provisioned
'

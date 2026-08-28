#!/usr/bin/env bash

set -euoE pipefail

image="${1:?Usage: $0 IMAGE}"

docker run --rm --entrypoint /bin/bash "$image" -lc '
  set -euo pipefail
  cd /tmp/.dotfiles

  test "$(whoami)" = linuxbrew
  test "$HOME" = /home/linuxbrew

  for executable in brew chezmoi fish mise nvim tmux; do
    command -v "$executable" >/dev/null
  done

  test -z "$(fish -c true)"
  mise exec -- nvim --headless +qa

  scripts/common/ansible.sh --run |
    tee /tmp/ansible-idempotence.log
  grep -Eq "changed=0 +unreachable=0 +failed=0" /tmp/ansible-idempotence.log
'

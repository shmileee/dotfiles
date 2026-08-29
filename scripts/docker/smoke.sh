#!/usr/bin/env bash

set -euoE pipefail

image="${1:?Usage: $0 IMAGE}"

docker run --rm --entrypoint /bin/bash "$image" -lc '
  set -euo pipefail
  cd "$HOME/ghq/personalgit/shmileee/dotfiles"

  printf "%s\n" "SMOKE phase=runtime-identity"
  test "$(whoami)" = linuxbrew
  test "$HOME" = /home/linuxbrew
  test -f .git/dotfiles-bootstrap-complete
  test "$(git remote get-url origin)" = https://github.com/shmileee/dotfiles.git
  test -z "$(git config --local --get http.sslVerify || true)"
  test -z "$(git config --local --get remote.origin.promisor || true)"

  printf "%s\n" "SMOKE phase=executables"
  for executable in brew chezmoi fish mise tmux; do
    command -v "$executable" >/dev/null
  done

  printf "%s\n" "SMOKE phase=startup"
  test -z "$(fish -c true)"
  mise exec -- nvim --headless +qa

  printf "%s\n" "SMOKE phase=idempotence"
  mise run reconcile |
    tee /tmp/ansible-idempotence.log
  grep -Eq "changed=0 +unreachable=0 +failed=0" /tmp/ansible-idempotence.log
'

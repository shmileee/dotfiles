#!/usr/bin/env bash

set -euoE pipefail

image="${1:?Usage: $0 IMAGE}"

docker run --rm --entrypoint /bin/bash "$image" -lc '
  set -euo pipefail
  receipt="$(find "$HOME/ghq/personalgit" -type f -path "*/.git/dotfiles-bootstrap-complete" -print -quit)"
  test -n "$receipt"
  repository="${receipt%/.git/dotfiles-bootstrap-complete}"
  cd "$repository"

  printf "%s\n" "SMOKE phase=runtime-identity"
  test "$(whoami)" = linuxbrew
  test "$HOME" = /home/linuxbrew
  test -f .git/dotfiles-bootstrap-complete
  case "$(git remote get-url origin)" in
    https://github.com/*/*.git) ;;
    *) exit 1 ;;
  esac
  test -z "$(git config --local --get http.sslVerify || true)"
  test -z "$(git config --local --get remote.origin.promisor || true)"

  printf "%s\n" "SMOKE phase=executables"
  for executable in bash brew chezmoi fish git-lfs mise tmux xclip; do
    command -v "$executable" >/dev/null
  done
  bash -c "(( BASH_VERSINFO[0] >= 4 ))"
  mise exec -- ansible-lint --version >/dev/null
  mise exec -- yamllint --version >/dev/null

  printf "%s\n" "SMOKE phase=startup"
  test -z "$(fish -c true)"
  test ! -e "$HOME/bin/ssm-session"
  test -z "$(git config --file "$HOME/.config/git/personal" --get commit.gpgsign || true)"
  test -z "$(git config --file "$HOME/.config/git/personal" --get gpg.ssh.program || true)"
  # nvim reports startup errors on stderr but still exits 0, so a bare exit
  # status check passes even when the config is broken. Reject any stderr.
  nvim_status=0
  nvim_output="$(mise exec -- nvim --headless +qa 2>&1 >/dev/null)" || nvim_status=$?
  if test "$nvim_status" -ne 0 || test -n "$nvim_output"; then
    printf "nvim headless startup failed (status=%s): %s\n" "$nvim_status" "$nvim_output" >&2
    exit 1
  fi

  printf "%s\n" "SMOKE phase=idempotence"
  mise run reconcile |
    tee /tmp/ansible-idempotence.log
  grep -Eq "changed=0 +unreachable=0 +failed=0" /tmp/ansible-idempotence.log
'

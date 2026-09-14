#!/usr/bin/env bats
#
# Assertions about a machine this repository has just provisioned: they read the
# real $HOME rather than a fixture, so they only hold immediately after a
# provisioning run and stay out of every default test task.
#
# Both provisioning jobs run this file, so an expectation that differs per
# platform is a branch inside its own test rather than a second copy in another
# CI definition that can drift out of step.

setup() {
  repository=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  personal_gitconfig=$HOME/.config/git/personal
  platform=$(uname -s)
  # mise resolves tasks and the reconciliation from the working directory, which
  # has to be the provisioned checkout rather than wherever bats was invoked.
  cd "$repository" || return 1
}

# Coverage the macOS provision job has never had. Widening these to Darwin is a
# deliberate change backed by a verified macOS run, not a side effect of moving
# the container's assertions into this file.
linux_only() {
  if [ "$platform" = Darwin ]; then
    skip "not asserted on macOS provisioning"
  fi
}

@test "the bash on PATH is new enough for the repository's scripts" {
  # macOS ships 3.2, so this also proves Homebrew's bash precedes it on PATH
  # without pinning the Homebrew prefix, which differs per architecture.
  bash -c '(( BASH_VERSINFO[0] >= 4 ))'
}

@test "the provisioned toolchain is on PATH" {
  for executable in brew chezmoi fish mise tmux; do
    if ! command -v "$executable" > /dev/null; then
      printf 'missing executable: %s\n' "$executable" >&3
      return 1
    fi
  done

  if [ "$platform" != Darwin ]; then
    # The clipboard bridge for Linux; macOS uses the base system's pbcopy.
    command -v xclip
  fi
}

@test "commit signing is configured on darwin only" {
  if [ "$platform" = Darwin ]; then
    test "$(git config --file "$personal_gitconfig" --get commit.gpgsign)" = true
  else
    test -z "$(git config --file "$personal_gitconfig" --get commit.gpgsign || true)"
  fi
}

@test "the ssh signing program resolves to an installed binary on darwin only" {
  if [ "$platform" = Darwin ]; then
    # Resolving the signer, rather than comparing it to the path the template
    # writes, is what proves the 1Password cask installed completely; an unset
    # value fails the same way.
    test -x "$(git config --file "$personal_gitconfig" --get gpg.ssh.program)"
  else
    test -z "$(git config --file "$personal_gitconfig" --get gpg.ssh.program || true)"
  fi
}

@test "the ssm session helper is installed on darwin only" {
  if [ "$platform" = Darwin ]; then
    # A cask wrapping a pkg installer, so a converged Homebrew run proves
    # nothing about the binary reaching PATH.
    command -v session-manager-plugin
    test -x "$HOME/bin/ssm-session"
  else
    # config/.chezmoiignore keeps the wrapper off machines without the plugin.
    test ! -e "$HOME/bin/ssm-session"
  fi
}

@test "provisioning lands on the linuxbrew user" {
  linux_only

  # Every Linux path in this repository — the Homebrew prefix, the fish login
  # shell, the published image — is written for that user and home.
  test "$(whoami)" = linuxbrew
  test "$HOME" = /home/linuxbrew
}

@test "the persistent checkout is a full clone of the public repository" {
  linux_only

  case "$(git remote get-url origin)" in
    https://github.com/*/*.git) ;;
    *) return 1 ;;
  esac
  # Bootstrap relaxes both to survive a machine without CA certificates and
  # clones shallowly for speed; neither may outlive the run that needed it.
  test -z "$(git config --local --get http.sslVerify || true)"
  test -z "$(git config --local --get remote.origin.promisor || true)"
}

@test "fish starts without emitting output" {
  linux_only

  test -z "$(fish -c true)"
}

@test "the mise-managed lint runtime resolves" {
  linux_only

  mise exec -- ansible-lint --version > /dev/null
  mise exec -- yamllint --version > /dev/null
}

@test "nvim starts headless without reporting errors" {
  linux_only

  # nvim reports startup errors on stderr but still exits 0, so a bare exit
  # status check passes even when the config is broken. Reject any stderr.
  nvim_status=0
  nvim_output="$(mise exec -- nvim --headless +qa 2>&1 > /dev/null)" || nvim_status=$?
  if [ "$nvim_status" -ne 0 ] || [ -n "$nvim_output" ]; then
    printf 'nvim headless startup failed (status=%s): %s\n' "$nvim_status" "$nvim_output" >&3
    return 1
  fi
}

@test "reconciling the provisioned machine converges" {
  reconcile_log=$BATS_TEST_TMPDIR/reconcile.log

  # `brew | update` refreshes the package index, and HOMEBREW_NO_AUTO_UPDATE
  # only suppresses the implicit refresh brew runs before other commands, never
  # that explicit one. Left in, this pass re-resolves `state: latest` against a
  # newer index and reports whatever upstream published since provisioning as
  # local drift. Skipping it pins this pass to the index provisioning installed
  # against, so it still asserts that every install and upgrade converges. The
  # container reaches the same state through the task's `not dockerized` guard.
  if ! ANSIBLE_SKIP_TAGS=homebrew_update mise run reconcile > "$reconcile_log" 2>&1 \
    || ! grep -Eq 'changed=0 +unreachable=0 +failed=0' "$reconcile_log"; then
    cat "$reconcile_log" >&3
    return 1
  fi
}

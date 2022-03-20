#!/usr/bin/env bash

set -euoE pipefail

install_brew() {
  echo "⚪ [homebrew] installing..."

  if command -v brew &> /dev/null; then
    echo "⚪ [homebrew] already installed."

    return 0
  fi

  export NONINTERACTIVE=1
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # shellcheck disable=SC2016
  if test "$(uname -s)" == "Linux"; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  brew analytics off
  echo "✅ [homebrew] installed!"
}

install_brew

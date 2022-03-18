#!/usr/bin/env bash

install_brew() {
  echo "⚪ installing brew..."

  if command -v brew &> /dev/null; then
    echo "⚪ brew is installed."

    return 0
  fi

  export CI=1
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if test "$(uname -s)" == "Linux"; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /etc/profile
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  brew analytics off
  echo "✅ homebrew installed!"
}

install_brew

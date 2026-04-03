#!/usr/bin/env bash

set -euoE pipefail

install_brew() {
	echo "⚪ [homebrew] installing..."

	if command -v brew &>/dev/null; then
		echo "⚪ [homebrew] already installed."

		return 0
	fi

	export NONINTERACTIVE=1
	bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# Add brew to PATH for the current session.
	# shellcheck disable=SC2016
	if test "$(uname -s)" == "Linux"; then
		echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>~/.bashrc
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	elif test "$(uname -s)" == "Darwin"; then
		eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
	fi

	brew analytics off
	echo "✅ [homebrew] installed!"
}

install_brew

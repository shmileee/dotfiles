#!/usr/bin/env bash

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

install_from_package_list() {
  export DEBIAN_FRONTEND=noninteractive
  apt="apt -qq -y --no-install-recommends"
  $apt update
  packages="$(awk '! /^ *(#|$)/' "$1")"
  xargs -a <(echo "$packages") -r -- echo "⚪ installing packages:"
  xargs -a <(echo "$packages") -r -- $apt install
}

install_from_package_list "${cwd}/essentials.apt"


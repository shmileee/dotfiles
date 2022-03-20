#!/usr/bin/env bash

set -euoE pipefail

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

apt="sudo apt -y"
$apt update

sudo add-apt-repository --yes --update ppa:ansible/ansible

install_from_package_list() {
  export DEBIAN_FRONTEND=noninteractive
  packages="$(awk '! /^ *(#|$)/' "$1")"
  xargs -a <(echo "$packages") -r -- echo "⚪ [apt] installing packages:"
  xargs -a <(echo "$packages") -r -- $apt --no-install-recommends install
}

install_from_package_list "${cwd}/essentials.apt"


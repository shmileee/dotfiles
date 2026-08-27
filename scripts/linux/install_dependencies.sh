#!/usr/bin/env bash

set -euoE pipefail

cwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apt=(sudo apt -y)
"${apt[@]}" update

"${apt[@]}" install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible

install_from_package_list() {
  export DEBIAN_FRONTEND=noninteractive
  mapfile -t packages < <(awk '! /^ *(#|$)/' "$1")
  printf '⚪ [apt] installing packages: %s\n' "${packages[*]}"
  "${apt[@]}" --no-install-recommends install "${packages[@]}"
}

install_from_package_list "${cwd}/essentials.apt"

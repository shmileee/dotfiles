#!/bin/sh

set -eu

usage() {
  printf 'Usage: %s IMAGE\n' "$(basename "$0")" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

command -v docker > /dev/null 2>&1 || {
  printf '%s: docker is required\n' "$(basename "$0")" >&2
  exit 127
}

docker run --rm --entrypoint /bin/sh "$1" \
  /tmp/.dotfiles/scripts/docker/container-smoke.sh

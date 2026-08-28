#!/bin/sh

set -eu

usage() {
  printf 'Usage: %s PHASE COMMAND [ARGUMENT]...\n' "$(basename "$0")" >&2
}

if [ "$#" -lt 2 ]; then
  usage
  exit 2
fi

phase=$1
shift
started_at=$(date +%s)

printf 'PROFILE phase=%s status=started\n' "$phase"

if "$@"; then
  status=0
else
  status=$?
fi

finished_at=$(date +%s)
printf 'PROFILE phase=%s status=%d elapsed_seconds=%d\n' \
  "$phase" "$status" "$((finished_at - started_at))"

exit "$status"

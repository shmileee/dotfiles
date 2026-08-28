#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <phase> <command> [arguments...]" >&2
  exit 2
fi

phase=$1
shift
started_at=$SECONDS

printf 'PROFILE phase=%s status=started\n' "$phase"

set +e
"$@"
status=$?
set -e

printf 'PROFILE phase=%s status=%s elapsed_seconds=%d\n' \
  "$phase" "$status" "$((SECONDS - started_at))"

exit "$status"

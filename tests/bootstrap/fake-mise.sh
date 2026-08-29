#!/bin/sh

set -eu

printf '%s\n' "$*" >> "$MISE_LOG"
case " $* " in
  *" exec -- uv "*) exit 0 ;;
  *) exit 97 ;;
esac

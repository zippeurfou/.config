#!/usr/bin/env bash
# New tmux session rooted at a folder (arg 1, default $PWD), auto-named from the
# folder, then switch to it (or attach from a bare shell). Idempotent: if the
# session already exists, just switch to it.
# Bound to: prefix N
set -uo pipefail   # no -e: a false test must not abort before the tmux switch

dir="${1:-$PWD}"
name="$(basename "$dir" | sed -E 's/^\.+//; s/[.:]/_/g')"   # folder name; tmux forbids . and :
[ -z "$name" ] && name="session"

tmux has-session -t="$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$dir"
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$name"
else
  tmux attach -t "$name"
fi

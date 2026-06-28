#!/usr/bin/env bash
# Prompt (in a centered popup) for a new window name, then create it rooted at
# the given dir. Empty input cancels — so you're forced to name the window.
# Bound to: prefix c / Cmd+T  (via display-popup -E)
set -uo pipefail

dir="${1:-$PWD}"
read -r -p "New window name: " name
[ -z "${name:-}" ] && exit 0
tmux new-window -c "$dir" -n "$name"

#!/usr/bin/env bash
# Colorized prefix-key cheatsheet, built from the REAL bindings. Bound to: prefix ?
# Keys are highlighted; descriptions come from each bind's -N note.
set -uo pipefail

{
  printf '\033[1;35m  tmux — prefix (C-b) keys\033[0m\n\n'
  tmux list-keys -N -T prefix | sort | awk '
    {
      if (match($0, /  +/)) { k = substr($0, 1, RSTART-1); n = substr($0, RSTART+RLENGTH) }
      else { k = $0; n = "" }
      printf "  \033[1;36m%-16s\033[0m %s\n", k, n
    }'
} | less -R

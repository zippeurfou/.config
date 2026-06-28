#!/usr/bin/env bash
# Fuzzy-find a project under ~/Projects and switch to (or create) a tmux session.
# Bound to: prefix + f  (runs inside a tmux display-popup)
#
# Session names are kept SHORT for fast finder nav + a tidy status bar:
#   1) explicit alias in ~/.config/tmux/sessionizer.aliases wins
#   2) otherwise: lowercase, separators -> '-', strip noise suffixes, trim
set -euo pipefail

BASE="${PROJECTS_DIR:-$HOME/Projects}"
ALIASES="${TMUX_SESSIONIZER_ALIASES:-$HOME/.config/tmux/sessionizer.aliases}"
NOISE="${TMUX_SESSIONIZER_NOISE:-gdp}"   # space-separated tokens stripped from the tail

selected="$(
  find "$BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort \
    | fzf --prompt="project ❯ " --reverse --border=rounded \
          --preview 'ls -la {}' --preview-window=right,50%
)"
[ -z "${selected:-}" ] && exit 0

base="$(basename "$selected")"

# 1) explicit alias:  <exact folder name>=<short session name>
name=""
if [ -f "$ALIASES" ]; then
  name="$(awk -F= -v k="$base" '!/^[[:space:]]*#/ && $1==k {print $2; exit}' "$ALIASES" || true)"
fi

# 2) otherwise auto-clean
if [ -z "$name" ]; then
  name="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr ' ._:' '----')"
  for tok in $NOISE; do name="${name%-$tok}"; done
  name="${name#-}"; name="${name%-}"
fi
name="$(printf '%s' "$name" | tr '.:' '__')"   # tmux forbids dots/colons

if ! tmux has-session -t="$name" 2>/dev/null; then
  tmux new-session -d -s "$name" -c "$selected"
fi
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$name"
else
  tmux attach -t "$name"
fi

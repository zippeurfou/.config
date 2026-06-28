#!/usr/bin/env bash
# Fuzzy-find a project/dir and switch to (or create) a tmux session.
# Bound to: prefix + f  /  Cmd+P   (runs inside a tmux display-popup)
#
# Candidates = immediate children of each ROOT (default: ~/Projects).
# Add more roots with SESSIONIZER_ROOTS, or standalone dirs with SESSIONIZER_EXTRAS
# (both space-separated). For a session from the folder you're *in*, use `prefix N`.
# For any dir you've merely visited, use `prefix Tab` (sessionx + zoxide).
# Session name = the folder name (an optional alias file can override per folder).
#
# NOTE: no `set -e` on purpose — fzf/empty-array exit codes must not abort the
# script before the tmux switch. We guard explicitly instead.
set -uo pipefail

ROOTS=("${PROJECTS_DIR:-$HOME/Projects}")
EXTRAS=()
[ -n "${SESSIONIZER_ROOTS:-}" ]  && read -r -a ROOTS  <<< "$SESSIONIZER_ROOTS"
[ -n "${SESSIONIZER_EXTRAS:-}" ] && read -r -a EXTRAS <<< "$SESSIONIZER_EXTRAS"

ALIASES="${TMUX_SESSIONIZER_ALIASES:-$HOME/.config/tmux/sessionizer.aliases}"

list_dirs() {
  local r d
  for r in "${ROOTS[@]}"; do find "$r" -mindepth 1 -maxdepth 1 -type d 2>/dev/null; done
  for d in "${EXTRAS[@]:-}"; do [ -n "$d" ] && [ -d "$d" ] && printf '%s\n' "$d"; done
  return 0
}

# Show only the folder name in the list (field 1); keep full path (field 2) for
# the preview and the result.
selected="$(list_dirs | sort -u \
  | awk -F/ '{print $NF "\t" $0}' \
  | fzf --delimiter='\t' --with-nth=1 --prompt='project ❯ ' --reverse \
        --border=rounded --preview 'ls -la {2}' --preview-window=right,50% \
  | cut -f2)"
[ -z "${selected:-}" ] && exit 0

base="$(basename "$selected")"

# Session name = the folder name. Optional alias file overrides per folder.
name=""
if [ -f "$ALIASES" ]; then
  name="$(awk -F= -v k="$base" '!/^[[:space:]]*#/ && $1==k {print $2; exit}' "$ALIASES")"
fi
[ -z "$name" ] && name="$base"
name="$(printf '%s' "$name" | sed -E 's/^\.+//; s/[.:]/_/g')"   # tmux forbids . and :
[ -z "$name" ] && name="session"

tmux has-session -t="$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$selected"
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$name"
else
  tmux attach -t "$name"
fi

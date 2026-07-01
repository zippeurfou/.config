#!/usr/bin/env bash
# Portable project finder for herdr — bound to prefix+F (the A/B alternative to the
# herdr-sessionizer plugin on prefix+f). Mirrors ~/.config/tmux/scripts/sessionizer.sh,
# but talks to herdr instead of tmux.
#
# fzf over immediate children of $ROOTS (default ~/Projects) + zoxide frecency dirs,
# then create-or-focus a workspace named after the folder.
#   ROOTS override:  SESSIONIZER_ROOTS="$HOME/Projects $HOME/work" (space-separated)
# No `set -e`: fzf/empty exit codes must not abort before the herdr call.
set -uo pipefail

H="${HERDR_BIN_PATH:-herdr}"
ROOTS=("${PROJECTS_DIR:-$HOME/Projects}")
[ -n "${SESSIONIZER_ROOTS:-}" ] && read -r -a ROOTS <<< "$SESSIONIZER_ROOTS"

list_dirs() {
  local r
  for r in "${ROOTS[@]}"; do
    [ -d "$r" ] && find "$r" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  done
  command -v zoxide >/dev/null 2>&1 && zoxide query -l 2>/dev/null
}

selected="$(list_dirs | awk 'NF && !seen[$0]++' \
  | fzf --prompt='project ❯ ' --reverse --border=rounded \
        --preview 'ls -la {} 2>/dev/null' --preview-window=right,50%)" || exit 0
[ -z "${selected:-}" ] && exit 0

name="$(basename "$selected" | sed -E 's/^\.+//; s/[.:]/_/g')"   # folder name; herdr labels dislike . :
[ -z "$name" ] && name="project"

# Best-effort: focus an existing workspace with this label, else create one.
wid="$("$H" workspace list 2>/dev/null \
  | jq -r --arg n "$name" \
      '[.. | objects | select(has("label"))] | map(select(.label==$n))
       | (.[0].workspace_id // .[0].id // empty)' 2>/dev/null)"

if [ -n "${wid:-}" ] && [ "$wid" != "null" ]; then
  "$H" workspace focus "$wid"
else
  "$H" workspace create --cwd "$selected" --label "$name" --focus
fi

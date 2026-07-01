#!/usr/bin/env bash
# prefix+o — keep only the focused pane (close the other panes in this tab).
# Mirrors your tmux `kill-pane -a`. Bound as a type="shell" custom command, so it
# receives HERDR_ACTIVE_* and runs detached.
# Defensive: if env/JSON is missing it simply does nothing (never closes blindly).
set -uo pipefail

H="${HERDR_BIN_PATH:-herdr}"
keep="${HERDR_ACTIVE_PANE_ID:-}"
tab="${HERDR_ACTIVE_TAB_ID:-}"
[ -z "$keep" ] && exit 0
[ -z "$tab" ]  && exit 0

"$H" pane list 2>/dev/null \
  | jq -r --arg tab "$tab" --arg keep "$keep" \
      '[.. | objects | select(has("pane_id"))] | .[]
       | select((.tab_id == $tab) and (.pane_id != $keep)) | .pane_id' 2>/dev/null \
  | while IFS= read -r p; do
      [ -n "$p" ] && "$H" pane close "$p"
    done

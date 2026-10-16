#!/usr/bin/env bash
# Browser-style back/forward through the windows you visit, across sessions.
#   record             hooks: note the window you're on now
#   back <client>      prefix Left  (Cmd+Left)
#   forward <client>   prefix Right (Cmd+Right)
# Rules: a place is a window (back lands on its active pane); each window appears
# once, and revisiting moves it to the newest end; any move that isn't back or
# forward drops everything ahead of you; closed windows and killed sessions are
# skipped; floax's scratch session is invisible.
#
# State lives in two global tmux user options (memory only):
#   @nav_hist  window ids, oldest first, e.g. "@3 @7 @12"
#   @nav_idx   index of the entry you're on
# Hooks run concurrently with the keys, so state is read in one tmux call and
# written in one tmux call; back/forward switch in that same call, so no hook can
# ever see the cursor moved but the switch not yet done.
# Runs under run-shell, which shows any output in a pane: stays silent, exits 0.
set -uo pipefail
exec >/dev/null 2>&1

FLOAX=$(tmux show -gqv @floax-session-name)
FLOAX=${FLOAX:-scratch}

# One atomic snapshot (a single tmux call) of the named client, or with no name,
# of the first client that isn't on the scratch session: you, not a floax popup.
# Sets client, win, sess, hist[], idx; then drops dead windows.
load() {
  local raw
  IFS='|' read -r client win raw idx sess <<<"$(
    tmux list-clients -F '#{client_name}|#{window_id}|#{@nav_hist}|#{@nav_idx}|#{session_name}' |
      awk -F'|' -v c="$1" -v floax="$FLOAX" '
        { s = $5; for (i = 6; i <= NF; i++) s = s "|" $i }   # session names may hold a |
        (c != "" && $1 == c) || (c == "" && s != floax) { print; exit }'
  )"
  [[ -n ${client:-} ]] || return 1
  read -ra hist <<<"${raw:-}"
  [[ ${idx:-} =~ ^[0-9]+$ ]] || idx=-1
  loaded="${hist[*]}|$idx"
  prune
}

# Drop windows that no longer exist: closed ones, and every window of a killed
# session. The cursor stays on its entry, or moves to the one before it if its
# own entry is the one that died.
prune() {
  local live w j=0 kept=() at=$idx
  live=" $(tmux list-windows -a -F '#{window_id}' | tr '\n' ' ') "
  for w in "${hist[@]}"; do
    if [[ $live == *" $w "* ]]; then
      kept+=("$w")
    elif ((j <= idx)); then
      ((at--))
    fi
    ((j++))
  done
  hist=("${kept[@]}")
  idx=$at
}

# A move that isn't back/forward: drop everything ahead of the cursor, then put
# the current window at the newest end (removing its older copy, if any).
jump() {
  local w kept=()
  for w in "${hist[@]:0:idx+1}"; do
    [[ $w == "$win" ]] || kept+=("$w")
  done
  hist=("${kept[@]}" "$win")
  idx=$((${#hist[@]} - 1))
}

record() {
  load "" || return 0
  if ((idx < 0)) || [[ ${hist[idx]:-} != "$win" ]]; then jump; fi
  [[ "${hist[*]}|$idx" == "$loaded" ]] && return 0   # nothing new (pruning included)
  tmux set -g @nav_hist "${hist[*]}" \; set -g @nav_idx "$idx"
}

step() {
  local i pane
  load "${2:-}" || return 0
  if [[ $sess == "$FLOAX" ]]; then tmux display-message -c "$client" "history: off in $FLOAX"; return 0; fi
  # The hook for your last move may not have run yet: count that move first, so
  # back returns to where you just were instead of skipping it.
  if ((idx < 0)) || [[ ${hist[idx]:-} != "$win" ]]; then jump; fi
  i=$((idx + $1))
  if ((i < 0)); then tmux display-message -c "$client" "history: no older place"; return 0; fi
  if ((i >= ${#hist[@]})); then tmux display-message -c "$client" "history: no newer place"; return 0; fi
  pane=$(tmux display -p -t "${hist[i]}" '#{pane_id}')
  [[ -n $pane ]] || return 0   # died since the snapshot; the next press skips it
  tmux set -g @nav_hist "${hist[*]}" \; set -g @nav_idx "$i" \; switch-client -c "$client" -t "$pane"
}

case ${1:-} in
  record) record ;;
  back) step -1 "${2:-}" ;;
  forward) step 1 "${2:-}" ;;
esac
exit 0

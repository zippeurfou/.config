#!/usr/bin/env bash
# Which opencode agents are waiting for you: feeds the "● N" status dot and the
# jump key. Callers:
#   set <pane> busy|waiting|clear   the opencode plugin, when its state changes
#   seen                            hooks: you're looking at a pane, so it's seen
#   next <client>                   prefix Up (Cmd+Up): go to the agent waiting longest
# Per-pane state (tmux pane options, memory only):
#   @agent_state   busy | waiting (needs you, not looked at yet) | seen
#   @agent_since   when it started waiting, to jump to the oldest first
# The dot only counts panes that are waiting AND still run opencode, so a crashed
# agent's leftover state never counts. Display: agent-attention.conf. Plugin:
# ~/.config/opencode/plugins/agent-attention.ts.
# Runs under run-shell, which shows any output in a pane: stays silent, exits 0.
set -uo pipefail
exec >/dev/null 2>&1

FLOAX=$(tmux show -gqv @floax-session-name)
FLOAX=${FLOAX:-scratch}

# Where you are: "client|pane|session" for the named client, or with no name, for
# the first client that isn't on floax's scratch session (you, not the popup).
view() {
  tmux list-clients -F '#{client_name}|#{pane_id}|#{session_name}' |
    awk -F'|' -v c="${1:-}" -v floax="$FLOAX" '
      { s = $3; for (i = 4; i <= NF; i++) s = s "|" $i }   # session names may hold a |
      (c != "" && $1 == c) || (c == "" && s != floax) { print; exit }'
}

# No explicit status refresh anywhere: tmux redraws every client's status line
# after any set-option, so the dot updates as soon as a state changes.
set_state() {   # set_state <pane> <busy|waiting|clear>
  local pane=$1 client here sess
  case $2 in
    busy) tmux set -p -t "$pane" @agent_state busy ;;
    clear) tmux set -p -t "$pane" -u @agent_state \; set -p -t "$pane" -u @agent_since ;;
    waiting)
      IFS='|' read -r client here sess <<<"$(view)"
      if [[ ${here:-} == "$pane" ]]; then
        tmux set -p -t "$pane" @agent_state seen   # it finished in front of you
      else
        tmux set -p -t "$pane" @agent_state waiting \; set -p -t "$pane" @agent_since "$EPOCHREALTIME"
      fi
      ;;
  esac
}

seen() {
  local client pane sess
  IFS='|' read -r client pane sess <<<"$(view)"
  [[ -n ${pane:-} ]] || return 0
  [[ $(tmux display -p -t "$pane" '#{@agent_state}') == waiting ]] || return 0
  tmux set -p -t "$pane" @agent_state seen
}

next() {
  local client pane sess target
  IFS='|' read -r client pane sess <<<"$(view "${1:-}")"
  [[ -n ${client:-} ]] || return 0
  if [[ $sess == "$FLOAX" ]]; then tmux display-message -c "$client" "agents: off in $FLOAX"; return 0; fi
  target=$(
    tmux list-panes -a -F '#{@agent_state}|#{pane_current_command}|#{@agent_since}|#{pane_id}' |
      awk -F'|' '$1 == "waiting" && $2 == "opencode" { print $3, $4 }' | sort -n | head -n1 | cut -d' ' -f2
  )
  if [[ -z $target ]]; then tmux display-message -c "$client" "agents: none waiting"; return 0; fi
  tmux set -p -t "$target" @agent_state seen \; switch-client -c "$client" -t "$target"
}

case ${1:-} in
  set) set_state "${2:-}" "${3:-}" ;;
  seen) seen ;;
  next) next "${2:-}" ;;
esac
exit 0

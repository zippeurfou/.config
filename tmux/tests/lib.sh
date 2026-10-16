# Shared harness for the tmux tests (nav-history.test.sh, agent-attention.test.sh).
# Source it, then set CONFS if needed, define test functions named like t01_* or
# a01_*, and end with run_tests.
#
# Safety: your live tmux server is never touched. Every test builds two throwaway
# servers on their own sockets, and teardown kills only those two:
#   inner (-L navtest-<pid>)   loads the confs under test and runs their scripts
#   outer (-L navouter-<pid>)  hosts a real client attached to inner, so tests type
#                              keys at it the way you would (C-b Left, iTerm's bytes)
# Before inner starts, a tmux shim goes first on its PATH, so every bare `tmux` a
# script runs (from inner's hooks and bindings) is pinned to the inner socket.
set -uo pipefail
unset TMUX TMUX_PANE   # never inherit the live server

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$LIB_DIR")
CONFS=("$ROOT/nav-history.conf")   # what start() loads; a test file may override
REAL_TMUX=$(command -v tmux)
INNER="navtest-$$"
OUTER="navouter-$$"
IDLE="exec sleep 86400"      # pane command: just a process that stays up
PASS=0
FAIL=0
MAIN=""                      # name of the test client (the one typing through outer)
INNER_PID=""                 # inner server's pid: its children are the hook jobs

SHIM=$(mktemp -d) || exit 1
printf '#!/bin/sh\nexec "%s" -L "%s" "$@"\n' "$REAL_TMUX" "$INNER" >"$SHIM/tmux"
chmod +x "$SHIM/tmux"
# A sleep binary named opencode: tmux reports its pane_current_command as
# "opencode", like a real agent, without starting one. It has to be coreutils'
# gsleep: macOS kills a copy of /bin/sleep (Apple platform binaries refuse to run
# from another path).
cp "$(command -v gsleep)" "$SHIM/opencode" 2>/dev/null ||
  { echo "harness: needs gsleep (brew install coreutils)" >&2; exit 2; }
# By absolute path, never through PATH: a PATH lookup that missed the shim would
# start your real opencode.
AGENT="exec '$SHIM/opencode' 86400"

ti() { "$REAL_TMUX" -L "$INNER" "$@"; }
to() { "$REAL_TMUX" -L "$OUTER" "$@"; }

SOCKDIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
stop_servers() {
  # Label-scoped on purpose: these two sockets are the only servers this file kills.
  [[ $INNER == navtest-* && $OUTER == navouter-* ]] || { echo "refusing: unexpected socket labels" >&2; exit 2; }
  to kill-server 2>/dev/null
  ti kill-server 2>/dev/null
  rm -f "$SOCKDIR/$INNER" "$SOCKDIR/$OUTER"   # tmux leaves the socket file behind
  return 0
}
# A background loop that runs a script (nav-history's hammer) must die before the
# shim is deleted: without the shim, its bare `tmux` could fall through to the
# default socket.
HAMMER_PID=""
cleanup() {
  [[ -n $HAMMER_PID ]] && { kill "$HAMMER_PID" 2>/dev/null; wait "$HAMMER_PID" 2>/dev/null; }
  stop_servers
  rm -rf "$SHIM"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- reporting ----------------------------------------------------------------

ok()  { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
bad() {
  FAIL=$((FAIL + 1))
  printf 'FAIL  %s\n      want: %s\n      got:  %s\n' "$1" "$2" "$3"
  diag
}

# Printed under every failure. A test file can redefine it.
diag() { printf '      history: %s\n' "$(dump_hist)"; }

# The history as session:window names, the cursor's entry in [brackets].
dump_hist() {
  local hist idx i=0 w out=""
  hist=$(ti show -gqv @nav_hist)
  idx=$(ti show -gqv @nav_idx)
  for w in $hist; do
    local name
    name=$(ti list-windows -a -F '#{window_id} #{session_name}:#{window_name}' | awk -v w="$w" '$1 == w { print $2 }')
    [[ $i == "$idx" ]] && out+="[${name:-$w}] " || out+="${name:-$w} "
    ((i++))
  done
  echo "${out:-<empty>} (idx=${idx:-unset})"
}

# --- waiting ------------------------------------------------------------------

# Poll a command until it succeeds, every 20ms, until a wall-clock deadline of $1
# seconds (a poll costs several tmux calls, so counting iterations would overshoot).
now_us() { echo "${EPOCHREALTIME/./}"; }
wait_for() {
  local deadline=$(($(now_us) + $1 * 1000000))
  shift
  while :; do
    "$@" && return 0
    (($(now_us) >= deadline)) && return 1
    sleep 0.02
  done
}

# Sync point, not an assertion. Hooks run scripts in the background, so wait
# until (1) no hook job is running under the inner server, for ~100ms in a row,
# and (2) the entry under the history's cursor is the window the client is on.
# (1) matters on its own: after a background change, (2) is already true before
# the hook has even run.
jobs_running() { pgrep -P "$INNER_PID" -f 'nav-history.sh|agent-attention.sh' >/dev/null; }
quiet() {   # true after 5 idle polls in a row (~100ms); false if still busy after 5s
  local idle=0 deadline=$(($(now_us) + 5000000))
  while ((idle < 5)); do
    (($(now_us) >= deadline)) && return 1
    if jobs_running; then idle=0; else idle=$((idle + 1)); fi
    sleep 0.02
  done
}
synced() {
  local hist idx cur
  hist=$(ti show -gqv @nav_hist)
  idx=$(ti show -gqv @nav_idx)
  cur=$(ti list-clients -F '#{client_name}|#{window_id}' | awk -F'|' -v c="$MAIN" '$1 == c { print $2 }')
  read -ra hist <<<"$hist"
  [[ $idx =~ ^[0-9]+$ && ${hist[idx]:-} == "$cur" ]]
}
settle() {
  quiet || echo "      (harness: hook jobs never went quiet)"
  wait_for 3 synced || echo "      (harness: history did not settle)"
}

# --- servers and clients ------------------------------------------------------

# Fresh servers: sessions a (a1, a2), b (b1), c (c1); the test client on a:a1.
# `start noconf` skips loading CONFS (the go-live test loads them later).
start() {
  stop_servers
  # SHELL=/bin/sh: pane commands run under sh, which reads none of your zsh files
  # (those rebuild PATH and would put Homebrew ahead of the shim).
  env PATH="$SHIM:$PATH" SHELL=/bin/sh "$REAL_TMUX" -L "$INNER" -f /dev/null \
    new-session -d -s a -n a1 -x 100 -y 20 "$IDLE"
  INNER_PID=$(ti display -p '#{pid}')
  # Mirror the live options that matter: killing a session hops to another one.
  ti set -g automatic-rename off \; set -g detach-on-destroy off \; set -g display-time 4000
  ti new-window -d -t a: -n a2 "$IDLE"
  ti new-session -d -s b -n b1 "$IDLE"
  ti new-session -d -s c -n c1 "$IDLE"
  if [[ ${1:-} != noconf ]]; then
    local conf
    for conf in "${CONFS[@]}"; do ti source-file "$conf"; done
  fi
  SHELL=/bin/sh "$REAL_TMUX" -L "$OUTER" -f /dev/null new-session -d -s host -x 100 -y 20 \
    "env TERM=xterm-256color '$REAL_TMUX' -L '$INNER' attach -t a"
  wait_for 3 client_up || { echo "harness: test client never attached" >&2; exit 2; }
  MAIN=$(ti list-clients -F '#{client_name}' | head -n1)
  [[ ${1:-} == noconf ]] || settle
}
client_up() { [[ -n $(ti list-clients -F x 2>/dev/null) ]]; }

# Where a client is, as session:window (default: the test client).
where() { ti list-clients -F '#{client_name}|#{session_name}:#{window_name}' | awk -F'|' -v c="${1:-$MAIN}" '$1 == c { print $2 }'; }
at() { [[ $(where) == "$1" ]]; }

# A second client attached to session $1 in its own outer window named "extra":
# what floax's popup is (a nested client of the same server). Prints its name.
attach_extra() {
  local before
  before=$(ti list-clients -F '#{client_name}')
  to new-window -d -t host: -n extra "env TERM=xterm-256color '$REAL_TMUX' -L '$INNER' attach -t '$1'"
  wait_for 3 clients_are 2 || { echo "harness: extra client never attached" >&2; exit 2; }
  ti list-clients -F '#{client_name}' | grep -vxF -- "$before"
}
clients_are() { [[ $(ti list-clients -F x | wc -l) -eq $1 ]]; }

# Move the test client the way Ctrl+1 / Cmd+O would, then let the history catch up.
go() {
  if [[ $(where) == "${1%%:*}":* ]]; then ti select-window -t "$1"; else ti switch-client -c "$MAIN" -t "$1"; fi
  wait_for 3 at "$1" || echo "      (harness: never reached $1)"
  settle
}

# Type at the test client, through the outer server.
key()  { to send-keys -t host: "$@"; }
back() { key C-b Left; }
fwd()  { key C-b Right; }

screen() { to capture-pane -p -t "host:${1:-0}"; }   # what a client shows: screen [outer window]
shows()  { screen "${2:-0}" | grep -qF -- "$1"; }    # shows <text> [outer window]

# The "Send Hex Code" text for a key in the CMD-layer profile, as send-keys -H
# arguments ("0x02 0x1b" -> "02 1b"); empty if the key isn't mapped.
iterm_bytes() {
  jq -r --arg k "$1" '.Profiles[0]."Keyboard Map"[$k].Text // empty' "$ROOT/iterm2-cmd-layer.json" | sed 's/0x//g'
}

# --- assertions ---------------------------------------------------------------

expect_at() {   # expect_at <description> <session:window>
  if wait_for 3 at "$2"; then ok "$1"; else bad "$1" "$2" "$(where)"; fi
}

# The key was handled (its message is on screen) and the client did not move.
expect_stays() {   # expect_stays <description> <session:window> <message>
  if wait_for 3 shows "$3" && at "$2"; then
    ok "$1"
  else
    bad "$1" "$2, with \"$3\" on screen" "$(where), status line: $(screen | tail -n1)"
  fi
}

# --- run ----------------------------------------------------------------------

# Runs every function named like t01_* / a01_*, in name order.
# ONLY=t07 runs just the tests whose name starts with that prefix.
run_tests() {
  local t
  for t in $(declare -F | awk '{ print $3 }' | grep -E '^[a-z][0-9][0-9]_'); do
    [[ -z ${ONLY:-} || $t == "$ONLY"* ]] && "$t"
  done
  stop_servers
  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
  ((FAIL == 0))
}

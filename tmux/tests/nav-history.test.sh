#!/usr/bin/env bash
# Tests for the navigation history: scripts/nav-history.sh + nav-history.conf.
# Run: bash ~/.config/tmux/tests/nav-history.test.sh   (ONLY=t07 for one test)
# Throwaway tmux servers only; see lib.sh for how the live server stays untouched.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
CONF="$ROOT/nav-history.conf"

# --- tests: each names the break it catches -----------------------------------

# Break: the window you attached to is never recorded, so the first move can't be undone.
t01_back_undoes_first_move_after_attach() {
  start
  go a:a2
  back
  expect_at "back undoes the first move after attaching (a2 -> a1)" a:a1
}

# Break: forward does nothing, or isn't the inverse of back.
t02_forward_undoes_back() {
  start
  go a:a2
  back
  expect_at "back (a2 -> a1)" a:a1
  settle
  fwd
  expect_at "forward undoes back (a1 -> a2)" a:a2
}

# Break: session switches (Cmd+O) aren't recorded, or back lands in the wrong session.
t03_back_crosses_sessions() {
  start
  go a:a2
  go b:b1
  go c:c1
  back
  expect_at "back crosses sessions (c1 -> b1)" b:b1
  settle
  back
  expect_at "back again (b1 -> a2)" a:a2
  settle
  back
  expect_at "back to the start (a2 -> a1)" a:a1
}

# Break: revisiting a place stacks a second copy, so walking back stops there twice.
t04_each_place_appears_once() {
  start
  go a:a2
  go b:b1
  go a:a2   # revisit: a2 moves to the newest end -> a1 b1 a2
  back
  expect_at "after a revisit, back goes to the place before it (a2 -> b1)" b:b1
  settle
  back
  expect_at "and the old copy is gone (b1 -> a1, not a2)" a:a1
}

# Break: a jump after back keeps the old forward entries, so back lands on one of them.
t05_jump_after_back_drops_what_was_ahead() {
  start
  go a:a2
  go b:b1
  back
  expect_at "back (b1 -> a2)" a:a2
  settle
  go c:c1   # a jump from the middle: b1 was ahead, so it's dropped -> a1 a2 c1
  back
  expect_at "back after the jump skips the dropped entry (c1 -> a2)" a:a2
}

# The kill tests walk the whole history back, and first point each session's
# current window somewhere that is NOT the history entry. A switch to a dead
# window can fall back to "some session's current window", which would otherwise
# land on the right place by luck.

# Break: back tries to go to a closed window instead of skipping it.
t06_closed_window_is_skipped() {
  start
  ti new-window -d -t a: -n a3 "$IDLE"
  go a:a2
  go b:b1
  go c:c1
  ti select-window -t a:a3   # background: a's current window is now a3
  ti kill-window -t a:a2     # history: a1 [a2] b1 c1
  settle
  back
  expect_at "back (c1 -> b1)" b:b1
  settle
  back
  expect_at "back skips a closed window (b1 -> a1, a2 is gone)" a:a1
}

# Break: back tries to go into a killed session instead of skipping it.
t07_killed_session_is_skipped() {
  start
  ti new-window -d -t c: -n c2 "$IDLE"
  go b:b1
  go c:c1
  go a:a2
  ti select-window -t c:c2   # background: c's current window is now c2
  ti kill-session -t b       # history: a1 [b1] c1 a2
  settle
  back
  expect_at "back (a2 -> c1)" c:c1
  settle
  back
  expect_at "back skips a killed session (c1 -> a1, b is gone)" a:a1
}

# Break: killing the session you're on leaves its window in the history, so back
# from wherever tmux moved you tries to return to it.
t08_killing_current_session_is_skipped() {
  start
  ti new-window -d -t a: -n a3 "$IDLE"
  go a:a2
  go b:b1
  go c:c1
  ti kill-session -t c       # detach-on-destroy off: tmux moves you to b, the most recent
  wait_for 3 at b:b1 || echo "      (harness: expected tmux to move the client to b:b1, got $(where))"
  settle
  ti select-window -t a:a3   # background: a's current window is now a3
  settle
  back
  expect_at "back after killing your own session (b1 -> a2)" a:a2
  settle
  back
  expect_at "and on to the start (a2 -> a1)" a:a1
}

# Break: pressing back at the oldest place fails silently (looks broken) or moves.
t09_back_at_oldest_says_so() {
  start
  back
  expect_stays "back at the oldest place stays put and says so" a:a1 "history: no older place"
}

# Break: pressing forward at the newest place fails silently (looks broken) or moves.
t10_forward_at_newest_says_so() {
  start
  go a:a2
  fwd
  expect_stays "forward at the newest place stays put and says so" a:a2 "history: no newer place"
}

# Break: a script changing the current window of a session you're NOT looking at
# (later: the agent jump, floax) gets recorded as if you had gone there.
t11_background_window_change_is_not_a_move() {
  start
  go b:b1
  ti select-window -t a:a2   # session a changes window while you're on b
  settle
  back
  expect_at "back ignores a background window change (b1 -> a1, never visited a2)" a:a1
}

# Break: visiting floax's scratch session lands in the history, so back stops there.
# Uses a custom @floax-session-name to prove the name is read, not hard-coded.
t12_scratch_session_is_not_recorded() {
  start
  ti set -g @floax-session-name popup
  ti new-session -d -s popup -n p1 "$IDLE"
  go b:b1
  ti switch-client -c "$MAIN" -t popup:p1
  wait_for 3 at popup:p1
  quiet
  go c:c1
  back
  expect_at "back skips floax's scratch session (c1 -> b1)" b:b1
}

# Break: opening the floax popup (a second client, on scratch) records the scratch
# window, so your next back goes nowhere.
t13_opening_the_popup_is_not_recorded() {
  start
  ti new-session -d -s scratch -n s1 "$IDLE"
  go a:a2
  attach_extra scratch >/dev/null
  quiet
  back
  expect_at "opening the popup doesn't touch your history (a2 -> a1)" a:a1
}

# Break: history keys pressed inside the popup move the popup (or you, behind it).
t14_keys_inside_the_popup_do_nothing() {
  start
  ti new-session -d -s scratch -n s1 "$IDLE"
  go a:a2
  local pop
  pop=$(attach_extra scratch)
  quiet
  to send-keys -t host:extra C-b Left
  if wait_for 3 shows "history: off in scratch" extra && [[ $(where "$pop") == scratch:s1 ]] && at a:a2; then
    ok "back inside the popup says it's off there, and nobody moves"
  else
    bad "back inside the popup says it's off there, and nobody moves" \
      "popup on scratch:s1 showing \"history: off in scratch\", you on a:a2" \
      "popup on $(where "$pop") showing \"$(screen extra | tail -n1)\", you on $(where)"
  fi
}

# Break: loading the config into a running server (going live with prefix r)
# records nothing until the first move, so that first move can't be undone.
t15_going_live_mid_session_can_undo_first_move() {
  start noconf
  ti source-file "$CONF"
  settle
  go a:a2
  back
  expect_at "after loading the config live, back undoes the first move (a2 -> a1)" a:a1
}

# Break: re-sourcing the config (prefix r) stacks another copy of each hook, so
# every move runs the script once more per reload.
t16_reloading_does_not_stack_hooks() {
  start
  ti source-file "$CONF"
  ti source-file "$CONF"
  local n
  n=$(ti show-hooks -g | grep -c 'nav-history.sh')
  if [[ $n == 2 ]]; then ok "reloading twice still leaves one hook per event"; else bad "reloading twice still leaves one hook per event" "2 hooks" "$n hooks"; fi
}

# Break: going back lands on the pane you arrived at instead of the one you left
# from (or a split adds history entries).
t17_back_lands_on_the_pane_you_left() {
  start
  ti split-window -d -t a:a1 "$IDLE"   # a1 now has panes .0 and .1; .0 active
  ti select-pane -t a:a1.1             # you move to the right split, then away
  go b:b1
  back
  local pane
  if wait_for 3 at a:a1; then
    pane=$(ti list-clients -F '#{client_name}|#{pane_index}' | awk -F'|' -v c="$MAIN" '$1 == c { print $2 }')
    if [[ $pane == 1 ]]; then ok "back lands on the split you left from (a1.1)"; else bad "back lands on the split you left from (a1.1)" "pane 1" "pane $pane"; fi
  else
    bad "back lands on the split you left from (a1.1)" a:a1 "$(where)"
  fi
  settle
  back
  expect_stays "splits aren't history entries (a1 is the oldest)" a:a1 "history: no older place"
}

# Break: back pressed before the hook for your last move has run skips the place
# you just left. Made deterministic by switching that hook off: the move to a2 is
# never recorded, exactly as if its hook were still pending.
t18_back_right_after_a_move_still_returns() {
  start
  ti set-hook -gu 'session-window-changed[42]'
  ti select-window -t a:a2
  wait_for 3 at a:a2
  quiet
  back
  expect_at "back right after an unrecorded move returns to where you were (a2 -> a1)" a:a1
}

# Break: hook jobs that read the history halfway through a back/forward (state
# saved, switch not done yet) mistake it for a new jump and scramble the history.
# Real hooks only rarely land in that gap, so a background loop runs `record`
# nonstop during the presses, the way a burst of hooks would.
t19_presses_during_hook_bursts_keep_history_intact() {
  start
  go a:a2
  go b:b1
  go c:c1
  hammer &
  HAMMER_PID=$!
  local round
  for round in 1 2 3; do
    key C-b Left C-b Left C-b Left
    expect_at "round $round: three quick backs during a hook burst (c1 -> a1)" a:a1
    key C-b Right C-b Right C-b Right
    expect_at "round $round: three quick forwards during a hook burst (a1 -> c1)" c:c1
  done
  kill "$HAMMER_PID" 2>/dev/null
  wait "$HAMMER_PID" 2>/dev/null
  HAMMER_PID=""
}
# Break: the iTerm CMD layer doesn't map Cmd+Left/Right, or sends bytes tmux
# doesn't read as prefix + arrow. Types the exact bytes from the profile JSON.
t20_iterm_cmd_arrows_drive_history() {
  start
  go a:a2
  local left right
  left=$(iterm_bytes 0xf702-0x300000)    # Cmd+Left
  right=$(iterm_bytes 0xf703-0x300000)   # Cmd+Right
  if [[ -z $left || -z $right ]]; then
    bad "iTerm profile maps Cmd+Left / Cmd+Right" "hex mappings in iterm2-cmd-layer.json" "left='$left' right='$right'"
    return
  fi
  key -H $left
  expect_at "Cmd+Left's bytes go back (a2 -> a1)" a:a1
  settle
  key -H $right
  expect_at "Cmd+Right's bytes go forward (a1 -> a2)" a:a2
}

# Runs the record hook back-to-back for up to 20s (killed when done). Two locks
# keep it on the inner server: the shim on PATH, and $TMUX naming the inner
# socket, which bare `tmux` falls back to if the shim were ever gone.
hammer() {
  local end=$(($(now_us) + 20000000))
  while (($(now_us) < end)) && [[ -x $SHIM/tmux ]]; do
    TMUX="$SOCKDIR/$INNER,0,0" PATH="$SHIM:$PATH" "$ROOT/scripts/nav-history.sh" record
  done
}

run_tests

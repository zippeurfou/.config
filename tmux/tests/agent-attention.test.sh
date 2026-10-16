#!/usr/bin/env bash
# Tests for the agent dot and jump: scripts/agent-attention.sh + agent-attention.conf.
# Run: bash ~/.config/tmux/tests/agent-attention.test.sh   (ONLY=a06 for one test)
# Throwaway tmux servers only; see lib.sh for how the live server stays untouched.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
CONF="$ROOT/agent-attention.conf"
CONFS=("$ROOT/nav-history.conf" "$CONF")   # live loads both; the jump relies on history for "back"

# --- helpers --------------------------------------------------------------------

pane_of() { ti display -p -t "$1" '#{pane_id}'; }

# Make a window's pane look like a running opencode agent. Aborts the run if the
# pane isn't running the fake (it must never be your real opencode).
agent() {
  ti respawn-pane -k -t "$1" "$AGENT"
  must_be_fake "$1"
}
must_be_fake() {
  wait_for 3 is_fake_agent "$1" || { echo "harness: $1 is not running the fake opencode; aborting" >&2; exit 2; }
}
is_fake_agent() { [[ $(ps -o command= -p "$(ti display -p -t "$1" '#{pane_pid}')" 2>/dev/null) == "$SHIM/opencode 86400" ]]; }

# What the opencode plugin does on a state change: run the script with its pane id.
# $TMUX names the inner socket, like the env of a real opencode pane would.
say() {   # say <session:window> <busy|waiting|clear>
  TMUX="$SOCKDIR/$INNER,0,0" PATH="$SHIM:$PATH" "$ROOT/scripts/agent-attention.sh" set "$(pane_of "$1")" "$2"
}

up() { key C-b Up; }

# The dot on the test client's status line ("● 2"), or nothing.
dot() { screen | tail -n1 | grep -o '● [0-9]*' | head -n1; }
dot_is() { [[ $(dot) == "$1" ]]; }
expect_dot() {   # expect_dot <description> <"● N" or "" for none>
  if wait_for 3 dot_is "$2"; then ok "$1"; else bad "$1" "dot '${2}'" "dot '$(dot)'"; fi
}

diag() {
  printf '      agents: %s\n' "$(ti list-panes -a -F '#{session_name}:#{window_name}=#{@agent_state}/#{pane_current_command}' | grep -v '=/' | tr '\n' ' ')"
  printf '      status: %s\n' "$(screen | tail -n1)"
  printf '      history: %s\n' "$(dump_hist)"
}

# --- tests: each names the break it catches -------------------------------------

# Break: no dot, a wrong count, or only agents in your own session counted.
a01_waiting_agents_light_the_dot() {
  start
  agent b:b1
  agent c:c1
  say b:b1 waiting
  expect_dot "one waiting agent in another session shows a dot" "● 1"
  say c:c1 waiting
  expect_dot "a second one counts too" "● 2"
}

# Break: agents that are still working count as waiting.
a02_busy_agents_dont_count() {
  start
  agent b:b1
  agent c:c1
  say b:b1 busy
  say c:c1 waiting
  expect_dot "a busy agent isn't counted, a waiting one is" "● 1"
}

# Break: looking at a waiting agent (any way, not just the jump key) leaves its dot on.
a03_visiting_an_agent_clears_its_dot() {
  start
  agent b:b1
  say b:b1 waiting
  expect_dot "waiting agent shows" "● 1"
  go b:b1
  go a:a1
  expect_dot "after you visit it (Cmd+O style) and leave, it's gone" ""
}

# Break: an agent finishing in the pane you're looking at lights the dot.
a04_agent_finishing_in_front_of_you_doesnt_count() {
  start
  agent a:a2
  agent b:b1
  go a:a2
  say a:a2 waiting   # finishes while you're on it
  say b:b1 waiting
  expect_dot "only the agent you're not looking at counts" "● 1"
  go a:a1
  expect_dot "and leaving the one you saw doesn't bring it back" "● 1"
}

# Break: a crashed opencode leaves a waiting state behind in a pane that's back to
# a shell, and it keeps counting (and Cmd+Up jumps to it).
a05_dead_agent_is_ignored() {
  start
  agent b:b1
  say b:b1 waiting
  say c:c1 waiting   # c1 runs sleep, not opencode: leftover state
  expect_dot "a pane no longer running opencode doesn't count" "● 1"
}

# Break: the jump goes nowhere, or not to the agent that has waited longest.
a06_up_jumps_to_the_agent_waiting_longest() {
  start
  agent b:b1
  agent c:c1
  say c:c1 waiting   # c1 first: it has waited longest
  say b:b1 waiting
  expect_dot "two waiting" "● 2"
  up
  expect_at "Up goes to the agent waiting longest (c1)" c:c1
  expect_dot "and that one no longer counts" "● 1"
}

# Break: Up revisits an agent you already saw, or fails silently when none is left.
a07_up_again_goes_to_the_next_then_says_none() {
  start
  agent b:b1
  agent c:c1
  say c:c1 waiting
  say b:b1 waiting
  up
  expect_at "first Up (c1)" c:c1
  settle
  up
  expect_at "second Up goes to the next one (b1)" b:b1
  expect_dot "nothing left waiting" ""
  settle
  up
  expect_stays "third Up says so and stays put" b:b1 "agents: none waiting"
}

# Break: the jump isn't recorded in the history, so back doesn't return.
a08_back_after_a_jump_returns_to_where_you_were() {
  start
  go a:a2
  agent c:c1
  say c:c1 waiting
  up
  expect_at "Up jumps to the agent (c1)" c:c1
  settle
  back
  expect_at "back returns to where you were (a2)" a:a2
}

# Break: once you've seen an agent, its next wait never lights the dot again.
a09_seen_agent_waiting_again_lights_again() {
  start
  agent b:b1
  say b:b1 waiting
  go b:b1
  go a:a1
  expect_dot "seen" ""
  say b:b1 busy      # you replied; it works again...
  say b:b1 waiting   # ...and finishes again
  expect_dot "its next wait lights the dot again" "● 1"
}

# Break: opencode exiting leaves its dot on.
a10_clear_removes_the_agent() {
  start
  agent b:b1
  say b:b1 waiting
  expect_dot "waiting" "● 1"
  say b:b1 clear
  expect_dot "cleared when opencode exits" ""
}

# Break: Up pressed inside the floax popup moves the popup (or you, behind it).
a11_up_inside_the_popup_does_nothing() {
  start
  ti new-session -d -s scratch -n s1 "$IDLE"
  agent b:b1
  say b:b1 waiting
  local pop
  pop=$(attach_extra scratch)
  quiet
  to send-keys -t host:extra C-b Up
  if wait_for 3 shows "agents: off in scratch" extra && [[ $(where "$pop") == scratch:s1 ]] && at a:a1; then
    ok "Up inside the popup says it's off there, and nobody moves"
  else
    bad "Up inside the popup says it's off there, and nobody moves" \
      "popup on scratch:s1 showing \"agents: off in scratch\", you on a:a1" \
      "popup on $(where "$pop") showing \"$(screen extra | tail -n1)\", you on $(where)"
  fi
}

# Break: re-sourcing the config (prefix r) stacks another copy of each hook.
a12_reloading_does_not_stack_hooks() {
  start
  ti source-file "$CONF"
  ti source-file "$CONF"
  local n   # window-pane-changed is a window hook, so it lives in the -w scope
  n=$({ ti show-hooks -g; ti show-hooks -gw; } | grep -c 'agent-attention.sh')
  if [[ $n == 3 ]]; then ok "reloading twice still leaves one hook per event"; else bad "reloading twice still leaves one hook per event" "3 hooks" "$n hooks"; fi
}

# Break: moving to an agent's split in the window you're in (no window or session
# change) doesn't mark it seen.
a14_moving_to_an_agents_split_clears_its_dot() {
  start
  ti split-window -d -t a:a1 "$AGENT"   # a1.1 is an agent; you're on a1.0
  must_be_fake a:a1.1
  TMUX="$SOCKDIR/$INNER,0,0" PATH="$SHIM:$PATH" "$ROOT/scripts/agent-attention.sh" set "$(pane_of a:a1.1)" waiting
  expect_dot "the agent in the split next to you is waiting" "● 1"
  ti select-pane -t a:a1.1
  expect_dot "moving to its split marks it seen" ""
}

# Break: the iTerm CMD layer doesn't map Cmd+Up, or sends bytes tmux doesn't read
# as prefix + Up. Types the exact bytes from the profile JSON.
a13_iterm_cmd_up_jumps() {
  start
  agent b:b1
  say b:b1 waiting
  local bytes
  bytes=$(iterm_bytes 0xf700-0x300000)   # Cmd+Up
  if [[ -z $bytes ]]; then
    bad "iTerm profile maps Cmd+Up" "a hex mapping in iterm2-cmd-layer.json" "none"
    return
  fi
  key -H $bytes
  expect_at "Cmd+Up's bytes jump to the waiting agent (b1)" b:b1
}

run_tests

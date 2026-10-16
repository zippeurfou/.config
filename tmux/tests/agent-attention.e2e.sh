#!/usr/bin/env bash
# End-to-end check with a REAL opencode: a TUI in a throwaway tmux server finishes
# a turn, the plugin reports it, and the dot lights up; Cmd+Up (prefix Up) jumps
# there and clears it; Cmd+Left (prefix Left) comes back. Re-run it after
# upgrading opencode: it's what proves the plugin still understands its events.
#
# Opt-in, not part of the regular suites: it starts real opencode (MCP servers
# disabled) in a temp dir and makes one small model call (default: Haiku 4.5, or
# set E2E_MODEL). That leaves one short session in opencode's history.
# Run: bash ~/.config/tmux/tests/agent-attention.e2e.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
CONFS=("$ROOT/nav-history.conf" "$ROOT/agent-attention.conf")
MODEL=${E2E_MODEL:-google-vertex-anthropic/claude-haiku-4-5@20251001}
OPENCODE=$(command -v opencode) || { echo "e2e: opencode not found" >&2; exit 2; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/agent-attention-e2e.XXXXXX")
# Every MCP server from your config, switched off for this run only.
NO_MCP=$(jq -c '{mcp: (.mcp // {} | with_entries(.value = {enabled: false}))}' "$HOME/.config/opencode/opencode.json")

state()    { ti display -p -t b:b1 '#{@agent_state}'; }
state_is() { [[ $(state) == "$1" ]]; }
dot()      { screen | tail -n1 | grep -o '● [0-9]*' | head -n1; }
dot_is()   { [[ $(dot) == "$1" ]]; }
expect_dot() { if wait_for 5 dot_is "$2"; then ok "$1"; else bad "$1" "dot '$2'" "dot '$(dot)'"; fi; }
diag() {
  printf '      b1 state: %s, command: %s\n' "$(state)" "$(ti display -p -t b:b1 '#{pane_current_command}')"
  printf '      b1 screen:\n'; ti capture-pane -p -t b:b1 | grep -v '^\s*$' | tail -12 | sed 's/^/        /'
}

e01_real_opencode_lights_the_dot_and_the_jump_clears_it() {
  start
  ti respawn-pane -k -t b:b1 \
    "cd '$WORK' && OPENCODE_CONFIG_CONTENT='$NO_MCP' exec '$OPENCODE' --model '$MODEL' --prompt 'Reply with exactly: ok'"
  if wait_for 180 state_is waiting; then
    ok "opencode finished its turn and the plugin reported waiting"
  else
    bad "opencode finished its turn and the plugin reported waiting" "@agent_state=waiting" "@agent_state='$(state)'"
    return
  fi
  expect_dot "the dot lights up on your status line" "● 1"
  key C-b Up
  expect_at "Up jumps to the waiting opencode" b:b1
  expect_dot "and the dot goes out" ""
  settle
  back
  expect_at "back returns to where you were" a:a1
}

run_tests
status=$?
rm -rf "$WORK"
exit $status

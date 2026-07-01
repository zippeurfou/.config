#!/usr/bin/env bash
# Prompt (in a centered popup) for a new name for the window you pressed the key
# on, then rename it. Empty input cancels — an accidental open leaves the name
# untouched. Starts blank (not pre-filled). Bound to: prefix ,
#
# Why the env stash: display-popup does NOT format-expand its command arg or its
# -e values, and resolving #{window_id} *inside* the popup can pick the wrong
# client when several are attached. So the binding captures the target window at
# key-press time (run-shell format-expands #{window_id} against the active pane)
# into the global tmux env var _RENAME_WIN, and we read it back here.
set -uo pipefail

raw="$(tmux show-environment -g _RENAME_WIN 2>/dev/null || true)"
target="${raw#_RENAME_WIN=}"
[ "$target" = "$raw" ] && target=""          # prefix not stripped -> unset/malformed
tmux set-environment -gu _RENAME_WIN 2>/dev/null || true   # clear the stash

read -r -p "Rename window: " name
[ -z "${name:-}" ] && exit 0

if [ -n "$target" ]; then
  tmux rename-window -t "$target" "$name"
else
  tmux rename-window "$name"                  # fallback: current window
fi

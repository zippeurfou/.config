# tmux integration: auto-attach on launch.
# Project finder is C-b f (portable) / Cmd+P (local) — no shell keybinding, by design.
# (Ctrl+F / Ctrl+G stay your file / grep finders from 30-keybindings.zsh.)
# See ~/.config/tmux/README.md.

# Auto-attach to a 'main' tmux session in interactive, local iTerm2 shells.
# Skipped when already inside tmux (so panes don't recurse).
# Opt out for a shell:  export NO_TMUX=1   before launching it.
if command -v tmux >/dev/null 2>&1 \
   && [[ $- == *i* && -z "$TMUX" && -z "$NO_TMUX" && "$TERM_PROGRAM" == "iTerm.app" ]]; then
  exec tmux new-session -A -s main
fi

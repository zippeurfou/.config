bindkey -v
# vi cursor shape per mode (defines zle-keymap-select/zle-line-init — needs vi mode first)
source "$ZDOTDIR/plugins/cursor_mode.zsh"
# tab cycles the completion menu
bindkey '\t' menu-select "$terminfo[kcbt]" menu-select
bindkey -M menuselect '\t' menu-complete "$terminfo[kcbt]" reverse-menu-complete
# hjkl navigation in the menu
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
# edit current command line in $EDITOR with 'v'
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line
# text objects: da" ci( etc.
autoload -Uz select-bracketed select-quoted
zle -N select-quoted
zle -N select-bracketed
for km in viopp visual; do
  bindkey -M $km -- '-' vi-up-line-or-history
  for c in {a,i}${(s..)^:-\'\"\`\|,./:;=+@}; do
    bindkey -M $km $c select-quoted
  done
  for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
    bindkey -M $km $c select-bracketed
  done
done

# --- fzf finders (atuin-style): Ctrl-F = files, Ctrl-G = grep-in-files ---
# Ctrl-F: pick file(s) under CWD, insert the path(s) on the command line.
_ff_widget() {
  emulate -L zsh
  local out; out="$(ff)"
  if [[ -n $out ]]; then
    local -a picks=("${(@f)out}")
    LBUFFER+="${(j: :)${(@q)picks}} "
  fi
  zle reset-prompt
}
zle -N _ff_widget
# Ctrl-G: live-grep file contents; ENTER opens the match in nvim at the line.
# accept-line so fif runs in normal shell context (become->nvim owns the tty).
_fif_widget() { emulate -L zsh; zle push-line; BUFFER='fif'; zle accept-line; }
zle -N _fif_widget
for km in viins vicmd; do
  bindkey -M $km '^F' _ff_widget
  bindkey -M $km '^G' _fif_widget
done

#!/usr/bin/env bash

zmodload zsh/complist
source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source "${HOME}/.iterm2_shell_integration.zsh"
source /opt/homebrew/etc/profile.d/z.sh
source /Users/mferradou/.config/zsh/zsh-z/zsh-z.plugin.zsh
source /Users/mferradou/.config/zsh/.zalias
source /Users/mferradou/.config/zsh/.zprivate # private stuff to not share publicly

if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi
# Single compinit, cached: -C skips the slow security audit on every start.
# (Delete ~/.zcompdump occasionally if completions for a new tool don't show up.)
autoload -Uz compinit
compinit -C

# node js stuff -- nvm is now lazy-loaded further down (see "lazy nvm" block)
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=5000
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt incappendhistory
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups
# autoload -U compinit && compinit
# zstyle ':completion:*' menu select
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
# fzf style do not work
# zstyle ':autocomplete:tab:*' insert-unambiguous yes
# zstyle ':autocomplete:tab:*' widget-style menu-select
# zstyle ':autocomplete:tab:*' fzf yes
# use tab instead of arrows
bindkey '\t' menu-select "$terminfo[kcbt]" menu-select
bindkey -M menuselect '\t' menu-complete "$terminfo[kcbt]" reverse-menu-complete
# Color completion for some things.
# http://linuxshellaccount.blogspot.com/2008/12/color-completion-using-zsh-modules-on.html
# zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# zstyle ':completion:*:*:*:*:default' list-colors ${(s.:.)LS_COLORS}
# formatting and messages
# http://www.masterzen.fr/2009/04/19/in-love-with-zsh-part-one/
# zstyle ':completion:*' verbose yes
# zstyle ':completion:*:descriptions' format "$fg[yellow]%B--- %d%b"
# zstyle ':completion:*:messages' format '%d'
# zstyle ':completion:*:warnings' format "$fg[red]No matches for:$reset_color %d"
# zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
# zstyle ':completion:*' group-name ''
setopt HIST_SAVE_NO_DUPS
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# directory customization
setopt AUTO_PUSHD           # Push the current directory visited on the stack.
setopt PUSHD_IGNORE_DUPS    # Do not store duplicates in the stack.
setopt PUSHD_SILENT         # Do not print the directory stack after pushd or popd.
# vim shell
bindkey -v
export KEYTIMEOUT=1
# change cursor
source "$ZDOTDIR/plugins/cursor_mode.zsh"
source "$ZDOTDIR/plugins/F-Sy-H/F-Sy-H.plugin.zsh"
# bd -> allow to jump to parent dir eg. if in a/b/c bd b will cd to it
source "$ZDOTDIR/plugins/bd.zsh"
# allow navigation with hkjl
# zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
# allow to edit with v command
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line
# allow da" and stuff like that
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
# do vim surround stuff not working with the syntax highlight so need to edit the other one to https://github.com/zsh-users/zsh-syntax-highlighting/tree/feature/redrawhook
# for now commenting
# autoload -Uz surround
# zle -N delete-surround surround
# zle -N add-surround surround
# zle -N change-surround surround
# bindkey -M vicmd cs change-surround
# bindkey -M vicmd ds delete-surround
# bindkey -M vicmd ys add-surround
# bindkey -M visual S add-surround

# eza completion

export FPATH="$ZDOTDIR/plugins/eza/completions/zsh:$FPATH"
# remove the echo
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
# add fzf with CTRl+R
eval "$(fzf --zsh)"
eval "$(starship init zsh)"
# direnv stuff
eval "$(direnv hook zsh)"
# java stuff
export SPARK_HOME="$HOME/spark-3.3.1-bin-hadoop3"
export PATH="$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin"

# TODO: Figure what version I have
# export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"
# Poetry
export PATH="/Users/mferradou/.local/bin:$PATH"

. "$HOME/.atuin/bin/env"

# GitHub CLI
export GITHUB_TOKEN=$(gh auth token)

eval "$(atuin init zsh)"
source ~/.local/share/bash-completion/completions/password

#lua rock stuff to remove

export LUA_DIR=/Users/mferradou/Developer/lua
export PATH="$PATH:${LUA_DIR}/bin"
export LUA_CPATH="${LUA_DIR}/lib/lua/5.1/?.so"
export LUA_PATH="${LUA_DIR}/share/lua/5.1/?.lua;;"
export MANPATH="${LUA_DIR}/share/man:$MANPATH"
export PATH="$PATH:$HOME/.luarocks/bin"
eval $(luarocks path --no-bin)
# --- lazy nvm -------------------------------------------------------------
# NVM's nvm.sh + `nvm use` was ~70% of shell startup (~2.7s). Instead we put
# the current default node bin on PATH instantly, and only source the full
# nvm script the first time you actually call nvm/node/npm/npx/corepack.
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

# Put the newest installed node version's bin on PATH right away (no nvm
# sourcing cost). We just pick the highest installed version under NVM_DIR so
# this is robust whatever the `default` alias points at.
() {
  setopt local_options null_glob no_nomatch
  local -a _nvm_bins
  _nvm_bins=( "$NVM_DIR"/versions/node/*/bin(N) )
  if (( ${#_nvm_bins} )); then
    # sort by version, take the newest
    _nvm_bins=( ${(On)_nvm_bins} )
    export PATH="${_nvm_bins[1]}:$PATH"
  fi
}

_load_nvm() {
  unset -f nvm node npm npx corepack 2>/dev/null
  # Homebrew installs nvm.sh here (NOT at $NVM_DIR/nvm.sh, which is just a symlink
  # target it creates lazily). Fall back to $NVM_DIR/nvm.sh for non-brew setups.
  if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    \. "/opt/homebrew/opt/nvm/nvm.sh"
  elif [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
  fi
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
}
# `nvm` becomes a shell function once nvm.sh is sourced, so call it by name.
nvm() { _load_nvm; nvm "$@"; }
# node/npm/npx/corepack are real binaries already on PATH; the stub only exists
# so that the first invocation also pulls in nvm's function/completions.
for _cmd in node npm npx corepack; do
  eval "$_cmd() { _load_nvm; command $_cmd \"\$@\"; }"
done
unset _cmd
# --- end lazy nvm ---------------------------------------------------------

# opencode search
export OPENCODE_ENABLE_EXA=1


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/mferradou/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/mferradou/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/mferradou/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/mferradou/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# bun completions
[ -s "/Users/mferradou/.bun/_bun" ] && source "/Users/mferradou/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

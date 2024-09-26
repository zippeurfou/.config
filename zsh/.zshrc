#!/usr/bin/env bash

zmodload zsh/complist
source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -U compinit
compinit
source "${HOME}/.iterm2_shell_integration.zsh"
source /opt/homebrew/etc/profile.d/z.sh
source /Users/mferradou/.config/zsh/zsh-z/zsh-z.plugin.zsh
source /Users/mferradou/.config/zsh/.zalias
source /Users/mferradou/.config/zsh/.zprivate # private stuff to not share publicly
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi

# node js stuff
export NVM_DIR="${HOME}/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
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
# java stuff
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
# Poetry
export PATH="/Users/mferradou/.local/bin:$PATH"

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# fzf BEFORE atuin so atuin wins Ctrl-R
eval "$(fzf --zsh)"
eval "$(direnv hook zsh)"
eval "$(starship init zsh)"
. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"
# password-store completion
[ -r ~/.local/share/bash-completion/completions/password ] && \
  source ~/.local/share/bash-completion/completions/password
# opencode
export OPENCODE_ENABLE_EXA=1
# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
# Google Cloud SDK
[ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"

# --- lazy nvm (nvm.sh only loads on first nvm/node/npm/npx/corepack call) ---
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
() {
  setopt local_options null_glob no_nomatch
  local -a b; b=( "$NVM_DIR"/versions/node/*/bin(N) )
  (( ${#b} )) && { b=( ${(On)b} ); export PATH="${b[1]}:$PATH"; }
}
_load_nvm() {
  unset -f nvm node npm npx corepack 2>/dev/null
  [ -s /opt/homebrew/opt/nvm/nvm.sh ] && \. /opt/homebrew/opt/nvm/nvm.sh
  [ -s /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm ] && \. /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm
}
nvm() { _load_nvm; nvm "$@"; }
for _c in node npm npx corepack; do eval "$_c() { _load_nvm; command $_c \"\$@\"; }"; done
unset _c

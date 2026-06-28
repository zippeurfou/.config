zmodload zsh/complist
# completion sources MUST be on FPATH before compinit
FPATH="/opt/homebrew/share/zsh-completions:$ZDOTDIR/plugins/eza/completions/zsh:$FPATH"
# zsh-autocomplete expects to load before the completion system is finalized
source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -Uz compinit
compinit -C

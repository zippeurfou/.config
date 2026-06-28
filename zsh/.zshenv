# Canonical zsh env (tracked). Bootstrapped by the ~/.zshenv stub.
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export EDITOR="nvim"
export VISUAL="nvim"
export VIMCONFIG="$XDG_CONFIG_HOME/nvim"
export MANPAGER='nvim +Man!'
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# don't forget to symlink this
# ln -s .zshrc ~/.zshrc
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export EDITOR="nvim"
export VISUAL="nvim"
# export TERM='rxvt-256color'
export VIMCONFIG="$XDG_CONFIG_HOME/nvim"
export MANPAGER='nvim +Man!'
. "$HOME/.cargo/env"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
export TERM='screen-256color'
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
eval "$(/opt/homebrew/bin/brew shellenv)"

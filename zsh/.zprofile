export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
export TERM='screen-256color'
# --no-rehash skips rebuilding all ~400 shims on every shell start (~1.45s -> ~0.18s).
# The shims already exist on disk; you only need `pyenv rehash` after installing a
# new Python version or a package that adds a CLI. Auto-virtualenv activation is
# unaffected (it comes from pyenv virtualenv-init's precmd hook below).
eval "$(pyenv init - --no-rehash)"
eval "$(pyenv virtualenv-init -)"
eval "$(/opt/homebrew/bin/brew shellenv)"

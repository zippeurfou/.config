# Syntax highlighting: MUST be the very last thing sourced in .zshrc.
# zsh-syntax-highlighting, not F-Sy-H: on zsh >= 5.9 it hooks zle-line-pre-redraw
# instead of wrapping every widget at load time. F-Sy-H's wrapping printed
# "unhandled ZLE widget" for widgets zsh-autocomplete binds at load but only
# creates at the first prompt.
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

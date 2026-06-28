# Thin orchestrator. Load order is encoded in rc.d/ numbering — see
# docs/plans/2026-06-28-zsh-config-reorg.md. Do NOT add logic here.
for _f in "$ZDOTDIR"/rc.d/[0-5]*.zsh(N); do source "$_f"; done
source "$ZDOTDIR/aliases.zsh"
# user functions (autoloaded)
fpath=("$ZDOTDIR/functions" $fpath)
autoload -Uz "$ZDOTDIR"/functions/*(N:t)
source "$ZDOTDIR/env.zsh"
[[ -r "$ZDOTDIR/.zwork"    ]] && source "$ZDOTDIR/.zwork"
[[ -r "$ZDOTDIR/.zprivate" ]] && source "$ZDOTDIR/.zprivate"
# syntax highlighting MUST be the final source
source "$ZDOTDIR/rc.d/99-highlight.zsh"
unset _f

# Generic, non-secret, machine-agnostic env (safe to track/share).
export PEEKABOO_AI_PROVIDERS=anthropic/claude-opus-4.5

# --- fzf: source command + atuin-like theme (consumed by ff/fif + builtins) ---
# Default file source: respect .gitignore, show dotfiles, skip .git/, follow symlinks.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# Colors use ANSI names so they inherit the terminal theme instead of clashing.
export FZF_DEFAULT_OPTS="
--height=80%
--layout=reverse
--border=rounded
--info=inline-right
--prompt='❯ '
--pointer='▶'
--marker='✓'
--color=hl:cyan,hl+:bright-cyan,info:dim,border:dim,spinner:yellow
--color=prompt:green,pointer:magenta,marker:green,header:dim,fg+:bold
--bind=ctrl-/:toggle-preview
--bind=ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up
"
# Built-in Ctrl-T (paste path) gets a bat preview so it matches Ctrl-F.
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window 'right,60%,border-left'"
# Built-in Alt-C (cd) previews the directory tree.
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza -aTL2 --color=always --icons=always {} 2>/dev/null || ls -A {}' --preview-window 'right,55%,border-left'"

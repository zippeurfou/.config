# Zsh Config Reorganization — Implementation Plan

> **For the executor:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this task-by-task.
> Work on a git branch. After EVERY task run the **Verification Harness** (below) in a *fresh* shell.
> If any task fails verification, STOP and use the **Escape Hatch**. Do not stack fixes.

**Goal:** Reorganize `~/.config/zsh` from two monolithic files (`.zshrc`, `.zalias`) plus a mixed secrets file (`.zprivate`) into a numbered `rc.d/` load chain with clear separation of concerns, a tracked/work/personal three-way secrets split, and an explicit, dependency-correct load order — without changing behavior or losing any secret.

**Architecture:** `.zshenv` (env) → `.zprofile` (login: pyenv/brew) → `.zshrc` (thin orchestrator) sources `rc.d/00..50` in order, then `aliases.zsh`, autoloads `functions/`, then `env.zsh` (tracked, non-secret), then `.zwork` (untracked work env+secrets) and `.zprivate` (untracked personal secrets), then finally `rc.d/99-highlight.zsh`. Load order is encoded in filename prefixes to make the four hard dependency rules un-violable.

**Tech stack:** zsh 5.9, homebrew tools (fzf/starship/direnv/atuin/keyring/gh), pyenv, lazy-nvm, F-Sy-H, zsh-autocomplete/autosuggestions.

---

## Hard load-order rules (must hold after reorg)

1. `brew shellenv` + `pyenv init` stay in `.zprofile` → PATH (incl. `/opt/homebrew/bin`, pyenv shims) is ready before any `.zshrc` tool-init or `keyring`/`gh`/`security` call.
2. `compinit` runs before any completion-style plugin or `compdef`.
3. `zsh-autocomplete` + `zsh-autosuggestions` load *before* `compinit` (preserves the currently-working order); F-Sy-H (syntax highlight) loads **dead last**.
4. `fzf` init before `atuin` init (last `Ctrl-R` binding wins → atuin).

## Decisions baked in (do NOT reintroduce the redundancies)

- **One syntax highlighter:** keep `F-Sy-H`; drop `zsh-syntax-highlighting` (old `.zshrc:55`).
- **One dir-jumper:** keep `zsh-z`; drop rupa/z (`source /opt/homebrew/etc/profile.d/z.sh`, old `.zshrc:7`).
- **eza FPATH before compinit** (old `.zshrc:104` was after compinit → completions never registered; this fixes it).
- **Dedupe okta lookup:** `PRESTO_PASSWORD` reuses `$OKTA_PASSWORD` instead of a second `keyring get`.
- **Move `zsh-z/` under `plugins/`** for consistency.
- **`#!/usr/bin/env bash` shebangs** removed from sourced zsh files.
- **GHTOKEN** is grouped as *work* (was beside Jenkins). `GITHUB_TOKEN=$(gh auth token)` is *personal*. If wrong, the owner moves one line.
- **Plaintext creds** in personal file (`LOLMATCHUP_*` API key + Postgres URL) are LEFT AS-IS for now (untracked) but flagged with a TODO comment to move to keychain later. Not in scope.

---

## ESCAPE HATCH (read first)

Two independent revert paths. Task 0 creates both.

**Path A — git (covers tracked files):**
```bash
git -C ~/.config checkout main -- zsh        # revert tracked zsh files to pre-reorg
# or abandon the whole branch:
git -C ~/.config checkout main && git -C ~/.config branch -D zsh-reorg
```

**Path B — filesystem snapshot (covers EVERYTHING incl. untracked/ignored secrets):**
```bash
# Restore the entire $ZDOTDIR from the tarball Task 0 created.
# Runnable even if the new config is broken (uses zsh -f, no rc files):
zsh -f ~/zsh-reorg-restore.sh
# or:
bash ~/zsh-reorg-restore.sh
```

**If a brand-new terminal is broken and won't give you a usable prompt:** open one with `zsh -f` (skips all rc files) or in iTerm run a non-login `sh`, then run Path B.

---

## Verification Harness (run after EVERY task, in a fresh shell)

Save this once as `~/zsh-reorg-verify.sh` during Task 0, then run `zsh -c '...'` against it. It must print `ALL GOOD` and the timing must stay ≤ ~1.4s.

```bash
# ~/zsh-reorg-verify.sh  — sanity-check a fresh login+interactive shell
set -e
clean() { grep -vE "RemoteHost|CurrentDir|ShellIntegration|can.t change option"; }

echo "== errors on fresh login shell (should be none) =="
err=$(zsh -l -i -c 'true' 2>&1 | clean | grep -iE "error|not found|no match|parse|bad pattern|command not found" || true)
[ -z "$err" ] && echo "  none" || { echo "  !!! $err"; exit 1; }

echo "== runtimes =="
zsh -l -i -c '
  echo "  node:   $(node --version 2>&1)"
  echo "  python: $(python --version 2>&1)"
  echo "  pyenv:  $(pyenv version-name 2>&1)"
  echo "  nvm:    $(nvm --version 2>&1)"
' 2>&1 | clean

echo "== key env vars present (lengths only) =="
zsh -l -i -c '
  for v in GHTOKEN OKTA_PASSWORD PRESTO_PASSWORD ANTHROPIC_API_KEY DD_API_KEY \
           JIRA_PERSONAL_TOKEN REDASH_API_TOKEN UV_DEFAULT_INDEX ARTIFACTORY_TOKEN \
           RAILWAY_TOKEN GITHUB_TOKEN GDPENV PRESTO_HOST GOOGLE_CLOUD_PROJECT; do
    val="${(P)v}"; printf "  %-22s %s\n" "$v" "${val:+set(${#val})}${val:-MISSING}"
  done
' 2>&1 | clean

echo "== aliases & functions resolve =="
zsh -l -i -c '
  whence -w v vim oc d sagemaker-who nvim_env opencode_setup s3yazi keyring_export 2>&1
' 2>&1 | clean

echo "== Ctrl-R owned by atuin, Ctrl-T by fzf =="
zsh -l -i -c 'bindkey "^R"; bindkey "^T"' 2>&1 | clean

echo "== timing (3 runs) =="
for i in 1 2 3; do /usr/bin/time zsh -l -i -c exit; done 2>&1 | grep real

echo "ALL GOOD"
```

A task “passes” when: no errors, all listed env vars `set`, all aliases/functions resolve, `^R` → `atuin-search`/`_atuin_search_widget`, timing ≤ ~1.4s.

---

## Task 0: Safety / escape hatch / baseline

**Files:**
- Create: `~/zsh-reorg-restore.sh`, `~/zsh-reorg-verify.sh`, `~/zsh-reorg-baseline.txt`, `~/zsh-reorg-snapshot-<ts>.tar.gz`
- Branch: `zsh-reorg`

**Step 1 — git branch:**
```bash
git -C ~/.config status --short        # note any pre-existing dirty state
git -C ~/.config checkout -b zsh-reorg
```

**Step 2 — full filesystem snapshot (captures untracked/ignored secrets too):**
```bash
ts=$(date +%Y%m%d-%H%M%S)
tar czf ~/zsh-reorg-snapshot-$ts.tar.gz -C ~/.config zsh
ls -la ~/zsh-reorg-snapshot-$ts.tar.gz
```

**Step 3 — write the restore script** (`~/zsh-reorg-restore.sh`):
```sh
#!/bin/sh
# Restore $ZDOTDIR entirely from the latest snapshot. Safe from a broken config.
snap=$(ls -t "$HOME"/zsh-reorg-snapshot-*.tar.gz 2>/dev/null | head -1)
[ -z "$snap" ] && { echo "no snapshot found"; exit 1; }
echo "Restoring ~/.config/zsh from $snap"
rm -rf "$HOME/.config/zsh.broken" 2>/dev/null
mv "$HOME/.config/zsh" "$HOME/.config/zsh.broken" 2>/dev/null
tar xzf "$snap" -C "$HOME/.config"
echo "Done. Open a new terminal. (broken copy saved at ~/.config/zsh.broken)"
```

**Step 4 — write `~/zsh-reorg-verify.sh`** (content from the Verification Harness section above).

**Step 5 — capture baseline** (the source of truth we must not regress):
```bash
zsh -l -i -c 'typeset -x' 2>/dev/null | sort > ~/zsh-reorg-baseline.txt   # all exported vars
wc -l ~/zsh-reorg-baseline.txt
sh ~/zsh-reorg-verify.sh > ~/zsh-reorg-baseline-verify.txt 2>&1; tail -5 ~/zsh-reorg-baseline-verify.txt
```

**Step 6 — commit the safety net:**
```bash
git -C ~/.config add zsh/docs/plans/2026-06-28-zsh-config-reorg.md
git -C ~/.config commit -m "docs(zsh): reorg plan + safety net"
```

**Verify:** `sh ~/zsh-reorg-verify.sh` prints `ALL GOOD`. `zsh -f ~/zsh-reorg-restore.sh` is syntactically valid (`sh -n ~/zsh-reorg-restore.sh`).

---

## Task 1: .gitignore + stop tracking caches

**Files:** Create `~/.config/zsh/.gitignore`

**Step 1 — write `.gitignore`:**
```gitignore
# secrets — never track
.zprivate
.zwork
# generated / machine-specific caches
.zcompdump*
.zsh_history
.zsh_history.LOCK
.zsh_sessions/
.zsh_sessions
# os / editor cruft
.DS_Store
# manual backups
*.bak-*
*.backup
*.pre-reorg
```

**Step 2 — untrack the caches already in git (keeps files on disk):**
```bash
cd ~/.config
git rm --cached zsh/.zcompdump zsh/.zcompdump.* zsh/.DS_Store 2>/dev/null || true
git status --short zsh
```

**Step 3 — commit:**
```bash
git -C ~/.config add zsh/.gitignore
git -C ~/.config commit -m "chore(zsh): gitignore caches/secrets, untrack generated files"
```

**Verify:** `git -C ~/.config check-ignore zsh/.zprivate zsh/.zwork zsh/.zcompdump` lists all three. `sh ~/zsh-reorg-verify.sh` → `ALL GOOD` (live shell unaffected — no sourced files changed yet).

---

## Task 2: Build new files ADDITIVELY (live `.zshrc` untouched)

> Rationale: new files aren’t sourced until Task 3, so the live shell and new terminals keep using the old config. Zero risk. We create everything, then cut over atomically.

### 2a — `rc.d/00-options.zsh`
**Create:** `~/.config/zsh/rc.d/00-options.zsh`
```zsh
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=5000
HISTDUP=erase
setopt appendhistory sharehistory incappendhistory
setopt hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
export KEYTIMEOUT=1
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
```

### 2b — `rc.d/10-completion.zsh`
**Create:** `~/.config/zsh/rc.d/10-completion.zsh`
```zsh
zmodload zsh/complist
# completion sources MUST be on FPATH before compinit
FPATH="/opt/homebrew/share/zsh-completions:$ZDOTDIR/plugins/eza/completions/zsh:$FPATH"
# zsh-autocomplete expects to load before the completion system is finalized
source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -Uz compinit
compinit -C
```
> **Contingency:** if verification shows autocomplete or completion broken, move the two `source ...autocomplete/autosuggestions` lines to AFTER `compinit -C` and re-verify. Note which order worked in the commit message.

### 2c — `rc.d/20-plugins.zsh`
**Create:** `~/.config/zsh/rc.d/20-plugins.zsh`
```zsh
source "${HOME}/.iterm2_shell_integration.zsh"
# zsh-z: frecent directory jumping (sole dir-jumper; rupa/z dropped)
source "$ZDOTDIR/plugins/zsh-z/zsh-z.plugin.zsh"
# bd: jump up to a named parent dir
source "$ZDOTDIR/plugins/bd.zsh"
```

### 2d — `rc.d/30-keybindings.zsh`
**Create:** `~/.config/zsh/rc.d/30-keybindings.zsh`
```zsh
bindkey -v
# vi cursor shape per mode (defines zle-keymap-select/zle-line-init — needs vi mode first)
source "$ZDOTDIR/plugins/cursor_mode.zsh"
# tab cycles the completion menu
bindkey '\t' menu-select "$terminfo[kcbt]" menu-select
bindkey -M menuselect '\t' menu-complete "$terminfo[kcbt]" reverse-menu-complete
# hjkl navigation in the menu
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
# edit current command line in $EDITOR with 'v'
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line
# text objects: da" ci( etc.
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
```

### 2e — `rc.d/40-tools.zsh`
**Create:** `~/.config/zsh/rc.d/40-tools.zsh`
```zsh
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
```

### 2f — `rc.d/50-path.zsh`
**Create:** `~/.config/zsh/rc.d/50-path.zsh`
```zsh
# Spark
export SPARK_HOME="$HOME/spark-3.3.1-bin-hadoop3"
export PATH="$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin"
# poetry / local bin
export PATH="$HOME/.local/bin:$PATH"
# Lua / luarocks
export LUA_DIR="$HOME/Developer/lua"
export PATH="$PATH:${LUA_DIR}/bin:$HOME/.luarocks/bin"
export LUA_CPATH="${LUA_DIR}/lib/lua/5.1/?.so"
export LUA_PATH="${LUA_DIR}/share/lua/5.1/?.lua;;"
export MANPATH="${LUA_DIR}/share/man:$MANPATH"
eval "$(luarocks path --no-bin)"
```

### 2g — `rc.d/99-highlight.zsh`
**Create:** `~/.config/zsh/rc.d/99-highlight.zsh`
```zsh
# Fast Syntax Highlighting — MUST be the very last thing sourced in .zshrc.
source "$ZDOTDIR/plugins/F-Sy-H/F-Sy-H.plugin.zsh"
```

### 2h — `aliases.zsh` (pure aliases)
**Create:** `~/.config/zsh/aliases.zsh`
```zsh
alias ls='eza -ahlF --color=always --icons=always --git --total-size --no-user --no-time --no-permissions '
alias ll='ls -lahF'
alias la='ls -alh'
alias dif="git diff --no-index"
alias tmuxk='tmux kill-session -t'
alias tmuxa='tmux attach -t'
alias tmuxl='tmux list-sessions'
alias vim="nvim_env"
alias nvim="nvim_env"
alias v="nvim_env"
alias create_project='create_project_function'
alias oc='opencode_setup'
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index
# moved out of .zprivate (it is an alias, not a secret)
alias sagemaker-who='_sagemaker_who() { aws sagemaker list-tags --resource-arn $(aws sagemaker describe-training-job --training-job-name "$1" --query "TrainingJobArn" --output text) --query "Tags[?Key==\`sagemaker:user-profile-arn\`].Value" --output text | awk -F"/" "{print \$NF}"; }; _sagemaker_who'
```

### 2i — `functions/` (autoloaded; filename == function name; file holds BODY only)
**Create these files** (each contains only the function *body*, no `name() { ... }` wrapper):

`~/.config/zsh/functions/nvim_env`
```zsh
emulate -L zsh
if test -e "$VIRTUAL_ENV" && test -f .python-version && test ! -f pyrightconfig.json; then
  echo "VIRTUAL_ENV detected adding pyrightconfig.json"
  sleep 2
  pyenv pyright
fi
if [[ -e "$VIRTUAL_ENV" && -f "$VIRTUAL_ENV/bin/activate" ]]; then
  source "$VIRTUAL_ENV/bin/activate"
  command nvim "$@"
  deactivate
else
  command nvim "$@"
fi
```

`~/.config/zsh/functions/create_project_function`
```zsh
emulate -L zsh
if [ $# -ne 2 ]; then
  echo "Usage: create_project {folder_name} {virtualenv_version}"
  return 1
fi
local folder_name="$1" virtualenv_version="$2"
cd ~/Projects || return
gh repo create "$folder_name" --private --license mit --gitignore=Python
gh repo clone "$folder_name"
cd ~/Projects/"$folder_name" || return
local readme_content="# $folder_name\n\n## Description\n\nAdd project description here.\n\n## Getting Started\n\nAdd instructions on how to get started with the project.\n"
echo "$readme_content" > README.md
uv init --python "$virtualenv_version" --name "$folder_name"
git add README.md
git commit -m "Initial commit with README"
git push
```

`~/.config/zsh/functions/keyring_export`
```zsh
emulate -L zsh
local var="$1" service="${2:-system}" value
value=$(security find-generic-password -s "$service" -a "$var" -w 2>/dev/null)
if [[ -z "$value" ]]; then
  echo "⚠️ Failed to load password for $var (service: $service)" >&2
  return 1
fi
export "$var=$value"
```

`~/.config/zsh/functions/opencode_setup` — copy body verbatim from old `.zalias:72-121` (the inside of the function, dropping the `opencode_setup() {` line and the closing `}`), prefixed with `emulate -L zsh`.

`~/.config/zsh/functions/s3yazi` — copy body verbatim from old `.zalias:123-138`, prefixed with `emulate -L zsh`.

`~/.config/zsh/functions/s3hmr`
```zsh
emulate -L zsh
s3yazi grubhub-gdp-search-data-science-data-assets-dev/shared/homepage_merchant_ranker_gdp
```

`~/.config/zsh/functions/zload_secrets` — parallel keychain loader used by `.zwork` and `.zprivate`:
```zsh
emulate -L zsh
# Read pipe-delimited specs from stdin and export each, looking up secrets in
# parallel and quietly (no job-control chatter). Spec lines:
#   sec|VAR|SERVICE        -> security find-generic-password -s SERVICE(-default system) -a VAR -w
#   krg|VAR|SERVICE|ACCT   -> keyring get SERVICE ACCT
# Blank lines and lines starting with # are ignored.
setopt local_options no_monitor no_notify
local tmp; tmp=$(mktemp) || return 1
local kind var a b
while IFS='|' read -r kind var a b; do
  [[ -z "$kind" || "$kind" == \#* ]] && continue
  case "$kind" in
    sec) { local v; v=$(security find-generic-password -s "${a:-system}" -a "$var" -w 2>/dev/null);
           [[ -n $v ]] && print -r -- "export ${var}=${(q)v}" >> "$tmp"; } & ;;
    krg) { local v; v=$(keyring get "$a" "$b" 2>/dev/null);
           [[ -n $v ]] && print -r -- "export ${var}=${(q)v}" >> "$tmp"; } & ;;
  esac
done
wait
source "$tmp"
rm -f "$tmp"
```

### 2j — `env.zsh` (tracked, non-secret, generic)
**Create:** `~/.config/zsh/env.zsh`
```zsh
# Generic, non-secret, machine-agnostic env (safe to track/share).
export PEEKABOO_AI_PROVIDERS=anthropic/claude-opus-4.5
```

### 2k — `.zwork` (UNTRACKED: work env + work secrets)
**Create:** `~/.config/zsh/.zwork`
```zsh
# WORK env + secrets (untracked). Only present on work machines.
export AWS_DEFAULT_PROFILE=data
export GDPENV=dev
export PRESTO_HOST="prod-ds-presto.gdp.data.grubhub.com."
export DEV_PRESTO_HOST="dev-presto.gdp.data.grubhub.com"
export ARTIFACTORY_USER="$(whoami)"
export GDP_ENV_CONFIG_B64="$(echo -n '{"env":"dev","aws_env":"gdpprod","artifactory_url":"https://grubhub.jfrog.io/artifactory/api/pypi/pypi-testing/simple","splunk_forwarders":"10.174.30.0:9997,10.174.49.85:9997","s3ArtifactBucket":"s3://grubhub-dl-artifacts-dev"}' | base64)"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
export GOOGLE_CLOUD_PROJECT=wonder-sandbox
export GOOGLE_GENAI_USE_VERTEXAI=True
export GOOGLE_CLOUD_LOCATION=global

# work secrets from keychain (parallel)
zload_secrets <<'SECRETS'
sec|JENKINS_TOKEN
sec|JENKINS_PREPROD_TOKEN
sec|JENKINS_PROD_TOKEN
sec|GHTOKEN
sec|PAGERDUTY_API_KEY
sec|ARTIFACTORY_TOKEN
sec|DD_APP_KEY|datadog
sec|DD_API_KEY|datadog
sec|JIRA_PERSONAL_TOKEN|opencode-mcp
sec|REDASH_API_TOKEN
sec|REDASH_USERNAME
sec|REDASH_BASE_URL
krg|OKTA_PASSWORD|okta|password
SECRETS
# PRESTO_PASSWORD is the same okta secret — reuse, don't look up twice
export PRESTO_PASSWORD="$OKTA_PASSWORD"

# UV artifactory index (two keychain lookups composed into one URL)
{
  _u=$(keyring get https://grubhub.jfrog.io/artifactory/api/pypi/pypi/simple username 2>/dev/null)
  _p=$(keyring get https://grubhub.jfrog.io/artifactory/api/pypi/pypi/simple password 2>/dev/null)
  if [[ -n $_u && -n $_p ]]; then
    export UV_DEFAULT_INDEX="https://${_u}:${_p}@grubhub.jfrog.io/artifactory/api/pypi/pypi/simple"
    export UV_INDEX="https://${_u}:${_p}@grubhub.jfrog.io/artifactory/api/pypi/pypi-testing/simple"
  fi
  unset _u _p
}
```

### 2l — `.zprivate` (UNTRACKED: personal secrets) — REWRITE
> The existing `.zprivate` is the source of these values; back it up first, then replace.
```bash
cp ~/.config/zsh/.zprivate ~/.config/zsh/.zprivate.pre-reorg
```
**Replace** `~/.config/zsh/.zprivate` with:
```zsh
# PERSONAL secrets / private env (untracked).
# TODO: move the two plaintext LOLMATCHUP creds below into the keychain.
export LOLMATCHUP_SUMMONER_NAME=zippeurfou
export LOLMATCHUP_REGION=euw1
# NOTE: copy the two REAL plaintext values from the current .zprivate (do NOT
# write them into this tracked plan doc — gitleaks will block the commit).
export LOLMATCHUP_PROD_TRAINING_DATA_API_KEY=<copy-from-current-.zprivate>
export LOLMATCHUP_PROD_PUBLIC_DATABASE_URL="<copy-from-current-.zprivate>"

# personal secrets from keychain (parallel). Unquoted heredoc so $USER expands.
zload_secrets <<SECRETS
sec|RAILWAY_TOKEN
sec|LOLMATCHUP_RIOT_API_KEY
sec|PLAYWRIGHT_MCP_EXTENSION_TOKEN
krg|ANTHROPIC_API_KEY|Claude Code|$USER
SECRETS

# GitHub CLI token (spawns gh once at startup; remove this line to lazy it)
export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
```

**Step — commit the additive files (tracked ones only; .zwork/.zprivate are gitignored):**
```bash
cd ~/.config
git add zsh/rc.d zsh/aliases.zsh zsh/functions zsh/env.zsh
git commit -m "feat(zsh): add rc.d split, aliases, functions, env (not yet wired)"
```

**Verify (Task 2):** New files don’t affect any shell yet. Run `zsh -n` on each new tracked file to check syntax:
```bash
for f in ~/.config/zsh/rc.d/*.zsh ~/.config/zsh/aliases.zsh ~/.config/zsh/env.zsh; do zsh -n "$f" && echo "ok: $f" || echo "SYNTAX ERR: $f"; done
sh ~/zsh-reorg-verify.sh   # still ALL GOOD via OLD config
```

---

## Task 3: Atomic cutover — new `.zshrc` + fixed `.zshenv`

### 3a — move `zsh-z` under `plugins/`
```bash
git -C ~/.config mv zsh/zsh-z zsh/plugins/zsh-z
```

### 3b — fix `.zshenv` drift (single source of truth)
**Replace** `~/.config/zsh/.zshenv` with:
```zsh
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
```
**Replace** `~/.zshenv` (the real HOME entrypoint) with a stub:
```zsh
# Bootstrap: zsh reads this first; point it at $ZDOTDIR then load the real env.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[ -r "$ZDOTDIR/.zshenv" ] && . "$ZDOTDIR/.zshenv"
```
**Delete** the stale template:
```bash
git -C ~/.config rm zsh/symlink/.zshenv && rmdir ~/.config/zsh/symlink 2>/dev/null || true
```

### 3c — back up old `.zshrc`/`.zalias`, write the orchestrator
```bash
cp ~/.config/zsh/.zshrc  ~/.config/zsh/.zshrc.pre-reorg
cp ~/.config/zsh/.zalias ~/.config/zsh/.zalias.pre-reorg
```
**Replace** `~/.config/zsh/.zshrc` with:
```zsh
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
```

**Step — VERIFY before committing (this is the risky moment):**
```bash
sh ~/zsh-reorg-verify.sh
# Compare exported vars against baseline (only acceptable diffs are intended moves):
zsh -l -i -c 'typeset -x' 2>/dev/null | sort > /tmp/after.txt
diff ~/zsh-reorg-baseline.txt /tmp/after.txt
```
**Acceptance:** `ALL GOOD`; the `diff` shows no *missing* vars (additions/reordering OK); timing ≤ ~1.4s; manually confirm in a real new iTerm tab: prompt renders (starship), typing shows autosuggestions + syntax highlight, `Ctrl-R` opens atuin, vi-mode cursor changes on `Esc`.

**If broken:** `zsh -f ~/zsh-reorg-restore.sh` (Path B) OR `git -C ~/.config checkout -- zsh/.zshrc` to restore just the orchestrator, then diagnose. Do not stack edits.

**Commit (only after green):**
```bash
git -C ~/.config add zsh/.zshenv zsh/.zshrc zsh/plugins/zsh-z
git -C ~/.config rm --cached zsh/symlink/.zshenv 2>/dev/null || true
git -C ~/.config commit -m "feat(zsh): wire orchestrator, fix .zshenv drift, move zsh-z into plugins"
```

---

## Task 4: Cleanup (only after Task 3 is verified & lived-with)

> Suggest waiting a day of real use before this task. Everything here is reversible via the snapshot.

**Step 1 — remove superseded files:**
```bash
cd ~/.config
git rm zsh/.zalias                          # superseded by aliases.zsh + functions/
git rm zsh/.zshrc.backup 2>/dev/null || true
rm -f zsh/.zshrc.pre-reorg zsh/.zalias.pre-reorg zsh/.zprivate.pre-reorg \
      zsh/.zshrc.bak-* zsh/.zprivate.bak-* zsh/.zprofile.bak-*
git rm --cached zsh/.zcompdump.* 2>/dev/null || true   # host-specific dump
```

**Step 2 — write a short load-order README:**
**Create:** `~/.config/zsh/README.md`
```markdown
# zsh config

Load order: `~/.zshenv` (stub) → `.zshenv` → `.zprofile` (login: pyenv/brew)
→ `.zshrc` (orchestrator) → `rc.d/00..50` → `aliases.zsh` → `functions/`
→ `env.zsh` → `.zwork` (work, untracked) → `.zprivate` (personal, untracked)
→ `rc.d/99-highlight.zsh` (last).

- `rc.d/` numbers encode dependencies: completion(10) before plugins(20),
  highlighter(99) last, fzf before atuin (40).
- Secrets: `.zwork` and `.zprivate` are gitignored. Both call `zload_secrets`
  (in `functions/`) to load keychain values in parallel.
- After installing a new Python/tool: run `pyenv rehash`.
- Regenerate completion cache: `rm ~/.config/zsh/.zcompdump*` and open a new shell.
```

**Step 3 — verify & commit:**
```bash
sh ~/zsh-reorg-verify.sh
git -C ~/.config add zsh/README.md zsh/.gitignore
git -C ~/.config commit -m "chore(zsh): remove legacy files, add load-order README"
```

---

## Final acceptance criteria

- [ ] Fresh `zsh -l -i` opens with **zero** stderr errors.
- [ ] Startup ≤ ~1.4s (login+interactive).
- [ ] `diff ~/zsh-reorg-baseline.txt` shows **no missing** exported vars.
- [ ] node/python/nvm/pyenv-venv all resolve; lazy-nvm loads on first `nvm`.
- [ ] All aliases + functions resolve (`v`, `oc`, `d`, `1`-`9`, `sagemaker-who`, `nvim_env`, `s3yazi`, `keyring_export`).
- [ ] `Ctrl-R` → atuin, `Ctrl-T` → fzf, vi-mode cursor + autosuggest + F-Sy-H highlight all work in a real tab.
- [ ] `git status` shows no secrets/caches tracked; `.zwork`/`.zprivate` ignored.
- [ ] Single highlighter, single dir-jumper (no duplicates).

## Merge / finish
After Task 4 verified and lived-with:
```bash
git -C ~/.config checkout main
git -C ~/.config merge --no-ff zsh-reorg -m "feat(zsh): reorganize config into rc.d + 3-way secrets split"
```
Keep `~/zsh-reorg-snapshot-*.tar.gz` for a week, then delete. (Do not push without your go-ahead.)

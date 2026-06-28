# zsh configuration

A modular zsh setup living under `$ZDOTDIR` (`~/.config/zsh`). The top-level
rc files are thin; all real configuration is split into small, single-purpose
files that load in a deterministic order. Secrets are kept out of git and read
from the macOS keychain at startup, in parallel, with no job-control noise.

Startup cost: **~1.1s** for a fresh login+interactive shell (was ~7s before the
2026-06 rewrite — see `docs/plans/2026-06-28-zsh-config-reorg.md` for the full
story and rationale).

---

## Load order

zsh reads these in order. `~/.zshenv` is the only file in `$HOME`; everything
else lives in `$ZDOTDIR`.

```
~/.zshenv                 stub: sets XDG_CONFIG_HOME + ZDOTDIR, then sources ↓
$ZDOTDIR/.zshenv          every shell: EDITOR, PATH bootstrap (cargo, opencode)
$ZDOTDIR/.zprofile        login shells only: pyenv, brew shellenv, TERM
$ZDOTDIR/.zshrc           interactive shells: the orchestrator ↓
        rc.d/00-options.zsh      history + shell options
        rc.d/10-completion.zsh   completion system (compinit) + autocomplete
        rc.d/20-plugins.zsh      iterm2, zsh-z, bd
        rc.d/30-keybindings.zsh  vi mode, menu nav, text objects
        rc.d/40-tools.zsh        fzf, starship, direnv, atuin, lazy-nvm, gcloud, bun
        rc.d/50-path.zsh         PATH/env for spark, lua, poetry
        aliases.zsh              shell aliases
        functions/*              autoloaded shell functions
        env.zsh                  non-secret, shareable env vars
        .zwork                   work env + work secrets   (untracked)
        .zprivate                personal secrets          (untracked)
        rc.d/99-highlight.zsh    syntax highlighting — MUST be last
```

A new iTerm2 tab opens a **login + interactive** shell, so it runs the whole
chain. `.zshrc` is intentionally ~12 lines — it only sources things in order.
Don't add logic there; put it in the right `rc.d/` file.

### Why the numbering matters (the hard rules)

The `rc.d/` prefixes encode real dependencies. Keep them:

1. `pyenv` + `brew shellenv` stay in `.zprofile` so `PATH` (and `/opt/homebrew/bin`)
   is ready before any tool init or keychain read in `.zshrc`.
2. `compinit` (10) runs before any plugin that registers completions (20+).
3. `fzf` is initialised before `atuin` (both in 40) so `Ctrl-R` ends up owned by
   atuin (last binding wins).
4. Syntax highlighting (`99-highlight.zsh`) is sourced **dead last**, after every
   widget and keybinding.

---

## File / directory map

| Path | Tracked? | Purpose |
|------|----------|---------|
| `~/.zshenv` | no (in `$HOME`) | bootstrap stub → sources `$ZDOTDIR/.zshenv` |
| `.zshenv` | yes | core env, every shell |
| `.zprofile` | yes | login-only: pyenv (`--no-rehash`), brew |
| `.zshrc` | yes | orchestrator (sources everything below) |
| `rc.d/*.zsh` | yes | the ordered config modules |
| `aliases.zsh` | yes | aliases only |
| `functions/` | yes | one autoloaded function per file |
| `env.zsh` | yes | non-secret, machine-agnostic env |
| `.zwork` | **no** (gitignored) | work env + work secrets |
| `.zprivate` | **no** (gitignored) | personal secrets |
| `plugins/` | yes | vendored plugins (F-Sy-H, zsh-z, bd, eza, cursor_mode) |
| `docs/plans/` | yes | design + implementation history |
| `.zcompdump*`, `.zsh_history`, `.zsh_sessions/` | no (gitignored) | generated caches |

---

## Secrets model

Three buckets, by sensitivity and machine:

- **`env.zsh`** (tracked) — non-secret, shareable env you're happy to commit.
- **`.zwork`** (gitignored) — work-internal env + work secrets (GDP, Google,
  Artifactory, Jenkins, Datadog, Jira, Redash, Okta). Drop this file only on a
  work machine.
- **`.zprivate`** (gitignored) — personal secrets (Anthropic, Railway, GitHub,
  hobby projects).

Secret **values** never live in these files — only the *names* and where to find
them. The actual values sit in the **macOS login keychain** and are read at
startup by the `zload_secrets` helper, which runs all lookups in parallel inside
a subshell (fast, and no `[N] …` job-control chatter).

> Both `.zwork` and `.zprivate` are matched by `.gitignore`, so they can never be
> committed. Verify with `git check-ignore zsh/.zwork zsh/.zprivate`.

---

## How to … (common tasks)

### Add a password / secret/token

Two steps: store the value in the keychain, then declare it.

**1. Store it in the keychain** (pick one):

```sh
# Using the keyring CLI (prompts for the value; this is what most existing
# secrets use). "service" and "account" are arbitrary labels you choose.
keyring set <service> <account>

# …or natively (no Python). -U updates if it already exists.
security add-generic-password -U -s <service> -a <account> -w '<value>'
```

**2. Declare it** by adding one line to `.zwork` (work) or `.zprivate`
(personal), inside the `zload_secrets <<'SECRETS' … SECRETS` block:

```
sec|VAR_NAME|service|account
```

- `sec|VAR_NAME` → reads service `system`, account `VAR_NAME` (the common case).
- `sec|VAR_NAME|service` → account defaults to `VAR_NAME`.
- `sec|VAR_NAME|service|account` → fully specified (use when the keychain
  account differs from the export name).

`VAR_NAME` is the environment variable that gets exported.

**Example** — add a `FOO_API_KEY` personal token:

```sh
keyring set foo-api "$USER"                       # paste the token when prompted
```
then in `.zprivate`:
```
sec|FOO_API_KEY|foo-api|$USER
```
Open a new shell; `echo $FOO_API_KEY` should show it. (The `.zprivate` heredoc is
*unquoted* — `<<SECRETS` — specifically so `$USER` expands. `.zwork` uses a
quoted `<<'SECRETS'` because none of its lines need expansion.)

To check a value is in the keychain without opening a shell:
```sh
security find-generic-password -s <service> -a <account> -w
```

### Add an alias
Edit `aliases.zsh`. Aliases only — if it needs logic or arguments, make it a
function instead.

### Add a function
Create `functions/<name>` containing the **body only** (no `name() { … }`
wrapper), starting with `emulate -L zsh`. It's autoloaded by name on first use.
Example `functions/hello`:
```zsh
emulate -L zsh
print "hi $1"
```

### Add a tool init or `eval "$(... init)"`
Put it in `rc.d/40-tools.zsh`. If it must run before completion, it belongs in
`10-completion.zsh`; if it only mutates `PATH`, use `50-path.zsh`.

### Add a plugin
Drop it under `plugins/` and `source` it from `rc.d/20-plugins.zsh` (or
`10-completion.zsh` if it provides completions and must load before `compinit`).
A syntax-highlighter must instead go in `99-highlight.zsh` (last).

### Refresh completions (new tool's completions not showing up)
The completion cache is trusted for speed (`compinit -C`). After installing a new
CLI:
```sh
rm ~/.config/zsh/.zcompdump*
exec zsh
```

### After installing a new Python or a pip package with a CLI
`pyenv` runs with `--no-rehash` at startup (that's the big startup win), so:
```sh
pyenv rehash
```

---

## Machine portability

The tracked files are machine-agnostic. To set up a new machine:

1. Clone/sync `~/.config` and create `~/.zshenv` as the bootstrap stub
   (sets `XDG_CONFIG_HOME` + `ZDOTDIR`, then sources `$ZDOTDIR/.zshenv`).
2. Install the tools the `rc.d/` files reference (brew, pyenv, starship, atuin,
   fzf, direnv, eza, …).
3. Create `.zprivate` (personal) and, on a work machine, `.zwork` — then store
   their secrets in that machine's keychain (`keyring set …`). On a personal
   machine, simply omit `.zwork`; `.zshrc` sources it only if present.

---

## Performance notes

- **nvm** is lazy-loaded — the newest installed node is put on `PATH` instantly;
  `nvm.sh` is sourced only on the first `nvm`/`node`/`npm`/`npx`/`corepack` call.
- **pyenv** uses `--no-rehash` (skips rebuilding ~400 shims every startup).
- **secrets** use native `security` (not the Python `keyring`), read in parallel
  in a subshell.

---

## Troubleshooting / recovery

- **A new tab errors or won't give a prompt:** open one that skips all rc files
  with `zsh -f`, then fix the offending file.
- **Full restore:** a snapshot from the last reorg lives in `$HOME`:
  ```sh
  zsh -f ~/zsh-reorg-restore.sh      # restores ~/.config/zsh from the snapshot
  ```
- **Sanity-check a fresh shell:** `sh ~/zsh-reorg-verify.sh` (prints `ALL GOOD`).
- **git history** is the canonical backup for tracked files; secrets/caches are
  intentionally untracked, so back those up separately if needed.

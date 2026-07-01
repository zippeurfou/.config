# herdr ⇄ tmux parity plan

Goal: reproduce the **feel & functionality** of `~/.config/tmux` in **herdr 0.7.1**, standalone
(launched directly in iTerm2, replacing tmux), keeping the `Ctrl+b` prefix so muscle memory
transfers. Not a 1:1 mapping — a faithful re-creation, plus notes on what can't match.

## Mental model (same as your tmux README)

| Your tmux | herdr | Status |
|---|---|---|
| session = project | **workspace** | ✓ |
| window = task | **tab** | ✓ |
| pane = view | **pane** | ✓ |
| `~/Projects` finder (`prefix f`) | workspace + plugin/script | ✓ (two paths) |

## Keymap (prefix = `Ctrl+b`, your nvim verbs)

| Action | tmux | herdr bind | How |
|---|---|---|---|
| split stacked / side | `s` / `v` | `prefix+s` / `prefix+v` | built-in (rebound) |
| pane nav | `h/j/k/l` | `prefix+h/j/k/l` | built-in |
| resize | `H/J/K/L` | `prefix+R` then `h/j/k/l`, `esc` | resize **mode** |
| zoom | `m` | `prefix+m` | built-in (default `z`) |
| kill pane | `q` | `prefix+q` | built-in (herdr default `x`; we swap) |
| **keep only this pane** | `o` | `prefix+o` | **script** `scripts/only-pane.sh` |
| new tab (named) | `c` | `prefix+c` | built-in + `prompt_new_tab_name` |
| next / prev tab | `n` / `b` | `prefix+n` / `prefix+b` | built-in |
| rename / kill tab | `,` / `&` | `prefix+,` / `prefix+&` | built-in |
| jump to tab N | `1`–`9` | `prefix+1..9` | built-in |
| switch project (sessionx) | `Tab` | `prefix+Tab` (+`prefix+w`) | built-in `workspace_picker` |
| **find project** (sessionizer) | `f` | `prefix+f` | **plugin** herdr-sessionizer |
| find project (portable A/B) | — | `prefix+F` | **script** `scripts/sessionizer.sh` |
| new project from cwd | `N` | `prefix+Shift+n` | built-in `new_workspace` |
| next / prev project | `)` / `(` | `prefix+Shift+→/←` | built-in (tmux `()` aren't valid herdr keys) |
| detach | `d` | `prefix+d` | built-in (herdr default `q`; we swap) |
| rename project | `$` | `prefix+Shift+w` | built-in (tmux `$` not a valid herdr key) |
| scratch (floax-ish) | `p` | `prefix+p` | **temp pane** (not a true float — see gaps) |
| copy mode (vi) | `[` | `prefix+[` | built-in (`v` select, `y` copy) |
| cheatsheet | `?` | `prefix+?` | built-in help panel |
| reload config | `r` | `prefix+r` | built-in |
| toggle sidebar | — | `prefix+Shift+b` | herdr-only |

The `d`=detach / `q`=kill swap is *more* tmux-faithful than herdr's defaults.

## What also carries over (built-in, no work)

- **tokyo-night** theme (`[theme] name="tokyo-night"`) — matches nvim tokyonight-night.
- **Clipboard / yank**: copy mode `y` → system clipboard (replaces tmux-yank).
- **Persistence**: live (detach keeps processes) + snapshot restore on restart (replaces resurrect+continuum). `pane_history=true` mirrors your `@resurrect-capture-pane-contents on`.
- **Splits open in current dir** (`[terminal] new_cwd="follow"`) — your `-c pane_current_path`.
- **Sensible defaults** (replaces tmux-sensible) + **mouse** on by default.
- **Named-tab popup** (`prompt_new_tab_name=true`) — replaces your `new-window.sh`.

## Honest gaps (can't match exactly)

1. **Tabs/status at top** — herdr is **sidebar-only** (left). No top status line. `prefix+Shift+b` toggles it.
2. **tokyo-night status widgets** (git/path/battery/etc.) — no status-line widget system; the sidebar shows workspace/agent state instead.
3. **nvim-session restore** (`@resurrect-strategy-nvim`) — herdr restores *agent CLI* sessions, not vim sessions; a restored pane comes back as a shell in the saved dir.
4. **floax persistent floating scratch** — `prefix+p` gives a temporary scratch *pane* (split, closes on exit), not a floating, process-preserving toggle. True floax needs a custom plugin.
5. **Rectangle copy select** (`C-v`) — herdr copy mode is vi-ish (`v`/`y`) but rectangle toggle isn't documented.

## Files this plan creates

- `~/.config/herdr/config.toml` — all the bindings + theme + UI + persistence above.
- `~/.config/herdr/scripts/sessionizer.sh` — `prefix+F` portable finder (fzf + zoxide → `herdr workspace create`).
- `~/.config/herdr/scripts/only-pane.sh` — `prefix+o` keep-only-this-pane.
- herdr-sessionizer plugin installed + its `projects.roots` pointed at `~/Projects`.

## Execution steps

1. Write `config.toml`.
2. Write `scripts/sessionizer.sh` + `scripts/only-pane.sh`, `chmod +x`.
3. `herdr plugin install andrewchng/herdr-sessionizer --yes`.
4. Point sessionizer at `~/Projects` (its `config.toml` under the plugin config dir).
5. Validate: TOML parses, `bash -n` scripts, `herdr plugin action list` shows `sessionizer.open`.

## Manual test checklist (you, inside herdr)

Launch: `herdr`. Then:

- [ ] `prefix ?` shows the keymap (with custom-command descriptions).
- [ ] `prefix s` / `prefix v` split stacked / side-by-side, in the current dir.
- [ ] `prefix h/j/k/l` move between panes.
- [ ] `prefix m` zoom toggles; `prefix q` kills a pane; `prefix o` closes the *other* panes.
- [ ] `prefix R` then `h/j/k/l` resizes; `esc` exits resize mode.
- [ ] `prefix c` prompts for a tab name; `prefix n`/`b` cycle tabs; `prefix 1..9` jump; `prefix ,` rename; `prefix &` kill.
- [ ] `prefix Tab` opens the project (workspace) switcher.
- [ ] `prefix f` opens herdr-sessionizer (fuzzy ~/Projects); `prefix F` opens the portable fzf+zoxide finder. Compare the two.
- [ ] `prefix Shift+n` makes a new project from the current dir; `prefix d` detaches; re-run `herdr` to reattach (processes survived).
- [ ] `prefix [` copy mode: `v` select, `y` copy, paste elsewhere.
- [ ] Theme looks like tokyonight; layout is compact (no gaps).

## Rollback

Everything is contained in `~/.config/herdr/`. To revert: `rm -rf ~/.config/herdr` (or just delete
`config.toml`), and `herdr plugin uninstall sessionizer`. Your tmux config is untouched.

# tmux configuration

A tmux config that **feels like nvim** (same window verbs), stays **invisible to nvim**
(zero keybinding conflicts), looks like **tokyonight-night**, and **persists sessions**
(detach / reattach / survive a terminal quit / reattach over SSH).

## Philosophy
The principles behind every decision below:

- **Invisible to the editor.** Navigation is prefix-based, so tmux intercepts *nothing* until you
  press `C-b` — your nvim keymaps always win. The prefix itself was chosen to avoid nvim too.
- **One canonical layer + one local alias.** `C-b <key>` is the complete set and works everywhere
  (including SSH); `Cmd+<key>` is just a faster *local* alias for the same actions; `Ctrl` is reserved
  for shell-prompt finders. Never three different keys for one action.
- **Cmd speaks Mac, `C-b` speaks tmux.** The two layers use different alphabets on purpose — each
  matches the muscle memory of its world instead of forcing a compromise.
- **Conventions over cleverness.** Sessions take their folder's name (no "smart" renaming); you name
  windows yourself. Predictable beats magic.
- **Generated keymap, single prose doc.** `C-b ?` builds its cheatsheet from the *actual* bindings, so
  the **keymap** can't drift. This README is the only prose doc — it *can* still fall out of sync, so the
  cheatsheet (not this file) is the source of truth for keys.
- **Portable & persistent first.** It behaves the same locally and over SSH, and sessions survive
  detach / quit / reboot. The Cmd layer is a convenience, never a requirement.
- **session = project · window = task · pane = view** — switch projects with the finder; never nest tmux.

## Setup (fresh machine)
Configs load from `~/.config/tmux/` (XDG) automatically — no `~/.tmux.conf` needed.

1. **Prerequisites** (Homebrew): `brew install tmux fzf zoxide bash jq coreutils` + a **Nerd Font**
   (for the status-bar glyphs). Optional extra widgets: `brew install gawk gnu-sed`.
2. **Plugin manager (TPM):**
   ```sh
   git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
   ```
3. **Install plugins:** start `tmux`, press `prefix I` (or run
   `~/.config/tmux/plugins/tpm/bin/install_plugins`).
4. **iTerm2 CMD layer:** the repo-root `setup.sh` symlinks the dynamic profile for you; to do it by hand instead:
   ```sh
   mkdir -p ~/Library/Application\ Support/iTerm2/DynamicProfiles
   ln -sf ~/.config/tmux/iterm2-cmd-layer.json \
     ~/Library/Application\ Support/iTerm2/DynamicProfiles/tmux-cmd-layer.json
   ```
   Then (always manual) iTerm2 → Settings → Profiles → **“tmux (CMD layer)”** → *Other Actions ▸ Set as Default* → reopen iTerm2.
5. **Shell auto-attach** is already wired in `~/.config/zsh/rc.d/55-tmux.zsh` (opt out per shell: `NO_TMUX=1`).

Plugins live under `plugins/` (git-ignored — reinstall anytime with `prefix I`).

## Decisions & rationale

| Decision | Choice | Why |
|---|---|---|
| Multiplexer | **tmux** | Mature, scriptable, on every server, best fzf-session ecosystem; pairs with iTerm2. |
| Terminal | **iTerm2** (unchanged) | Keep what works; OSC52 clipboard works out of the box. |
| Prefix | **`Ctrl+b`** (default) | Kept simple. Trade-off: tmux grabs `C-b`, so nvim's built-in page-back yields (you scroll with `C-u`/`C-d`). |
| Pane navigation | **Prefix-based** (`prefix h/j/k/l`) | tmux intercepts **nothing** without the prefix → every nvim key (`<C-w>`, copilot `<C-j>`, leap `s`/`S`, `<C-Space>` completion/treesitter) is untouched. |
| Window verbs | **Mirror nvim `<C-w>`** | `prefix` then the same letter you'd use after `<C-w>`: `s`/`v` split, `m` zoom, `q` kill, `o` only. |
| Session finder | **sessionx** (`prefix Tab`) + **sessionizer** (`prefix f`) | sessionx = search/create/kill/preview live sessions; sessionizer = jump into a `~/Projects` repo. |
| Floating pane | **floax** (`prefix p`) + native (`prefix *`) | floax = persistent toggle scratch (tmux 3.7's native floating is still "initial"). |
| Theme | **tokyo-night-tmux** | Direct palette match to your nvim `tokyonight-night` (not catppuccin). |
| Persistence | **resurrect + continuum** | Auto-save every 15 min, auto-restore on start. |
| Navigation history | **own script + hooks** (`scripts/nav-history.sh`) on `prefix ←/→` + `Cmd+←/→` | tmux only toggles one step back (`last-window`, `switch-client -l`), and those keys went to hjkl/HJKL anyway. A place is a **window**, so hopping between splits doesn't flood it. Each window appears **once**, like vim's jumplist. tmux-jumplist exists, but it records every pane change and had 1 star. |
| Agent attention | **a `● N` dot + `prefix ↑` / `Cmd+↑`**, fed by an opencode plugin | Sound and desktop notifications interrupt, and herdr was too much. The dot says *whether* agents wait, the key takes you *there*, `Cmd+←` brings you back. tmux counts the dot at every redraw from per-pane state, so no shared counter can go stale. |

### The mental model
`Ctrl+b` then a verb. Because nav is prefix-based, tmux is **invisible until you press the
prefix** — so inside nvim nothing breaks. The verbs mirror your nvim `<C-w>` muscle memory.

## Keymap cheatsheet (prefix = `Ctrl+b`)

### Panes
| Keys | Action | nvim analogue |
|---|---|---|
| `prefix s` | split stacked (horizontal) | `<C-w>s` |
| `prefix v` | split side-by-side (vertical) | `<C-w>v` |
| `prefix h/j/k/l` | move between panes | `<C-w>h/j/k/l` |
| `prefix H/J/K/L` | resize pane (repeatable) | — |
| `prefix m` | zoom / maximize pane | `<C-w>m` (your TZFocus) |
| `prefix q` | kill this pane | `<C-w>q` |
| `prefix o` | keep only this pane | `<C-w>o` |
| `prefix *` | native floating pane (tmux 3.7) | — |

### Windows (tabs)
| Keys | Action |
|---|---|
| `prefix c` | new window — **names it in a popup** (empty field; empty input cancels) |
| `prefix n` / `prefix b` | next / previous window |
| `prefix 1`…`9` | jump to window N |
| `prefix ,` | rename window — **renames it in a popup** (empty field; empty input cancels) |
| `prefix &` | kill window (confirm) |

### Sessions (one window, many persistent sessions — switch, don't tab them)
| Keys | Action |
|---|---|
| `prefix Tab` | **sessionx** — switch / create / **kill (`Ctrl-K`)** / rename (`Ctrl-R`) |
| `prefix f` | **sessionizer** — fuzzy-find a `~/Projects` repo → switch/create session |
| `prefix N` | **new session from the current folder** (auto-named) |
| `prefix )` / `prefix (` | next / previous session |
| `prefix d` | detach (session keeps running in the background) |
| `prefix $` | rename session |

### History (back / forward through the windows you visited, across sessions)
| Keys | Action |
|---|---|
| `prefix ←` / `Cmd+←` | back to the previous place |
| `prefix →` / `Cmd+→` | forward again (only after going back) |

See **Navigation history** below for the rules.

### Agents (opencode waiting for you)
| Keys | Action |
|---|---|
| `prefix ↑` / `Cmd+↑` | go to the agent that has waited longest; again for the next one |

The bar shows `● N` on the right while N agents wait, and nothing otherwise. See **Agent dot** below.

### Floating & misc
| Keys | Action |
|---|---|
| `prefix p` / `prefix P` | floax floating scratch — toggle / menu |
| `prefix *` | native floating pane (tmux 3.7 ad-hoc; `p` is the daily scratch) |
| `prefix [` | copy mode (vi keys: `v` select, `y` copy) |
| `prefix ?` | **colorized cheatsheet** popup (built from your real binds) |
| `prefix r` | reload config |

**Floating-pane controls (while the floax pane is open):** the title shows `C-M-s/b/f/r/e/d`
(Ctrl+**Meta**). macOS doesn't send Meta by default, so either use the **`prefix P` menu**
(plain keys: `-`/`+` size, `f` fullscreen, `r` reset, `e` embed) or set iTerm2 →
Profiles ▸ Keys ▸ **Right Option key = Esc+** to make `Ctrl+⌥(right)+s` etc. work.

### From the shell
- `Ctrl+F` → file finder · `Ctrl+G` → grep (your existing zsh finders; unchanged).
- Opening iTerm2 **auto-attaches** to a `main` session (see Shell integration). Opt out: `NO_TMUX=1`.
- Aliases (kept): `tmuxl` list · `tmuxa <name>` attach · `tmuxk <name>` kill

## Navigation history
Browser-style back/forward through the windows you visit. Logic in `scripts/nav-history.sh`,
wiring in `nav-history.conf`.
- **A place is a window.** Going back lands on the pane you were last in there; moving between
  splits doesn't add entries.
- **Each window appears once.** Revisiting one moves it to the newest end, so walking back never
  stops at the same place twice.
- **Browser rules.** Forward only works after back. Any other move (`Ctrl+1-9`, `Cmd+O`, `prefix f`,
  ...) drops whatever was ahead.
- **It skips closed windows and killed sessions.** floax's `scratch` session is invisible. It's never
  recorded, and the keys say `history: off in scratch` there.
- **At either end** you get `history: no older place` / `history: no newer place` and stay put.
- **Memory only.** It starts empty after a tmux server restart. Loading the config records where you
  are, so you can undo the first move after `prefix r`.
- `tmux.conf` sources `nav-history.conf` after TPM, so continuum's restore at startup doesn't fill
  the history.
- **Tests.** Run `bash ~/.config/tmux/tests/nav-history.test.sh`. They spin up throwaway tmux servers
  on their own sockets and never touch your live one.

## Agent dot
A `● N` on the right of the status bar while opencode agents wait for you, in any session. The
opencode plugin (`~/.config/opencode/plugins/agent-attention.ts`) reports each pane's state;
`scripts/agent-attention.sh` and `agent-attention.conf` do the rest.
- **Waiting** means the turn ended (the main session and all its subagents are done) or a permission
  or question prompt is open.
- **Looking at it clears it**, however you get there: `Cmd+↑`, `Ctrl+1-9`, `Cmd+O`, or moving into
  its split. An agent that finishes in the pane you're on never lights the dot. Its next wait does.
- **`Cmd+↑` goes to the agent waiting longest**, then the next. With none left it says
  `agents: none waiting`. The jump lands in the history, so `Cmd+←` takes you back.
- **Only live agents count.** A pane that no longer runs opencode (it crashed) is ignored, and
  quitting opencode clears its pane.
- **The plugin loads when opencode starts**, so an agent that was already running when you installed
  or changed it reports nothing until you restart it.
- floax's `scratch` session is off for the jump too (`agents: off in scratch`).
- **Tests.** `bash ~/.config/tmux/tests/agent-attention.test.sh` covers the tmux side, and
  `bun test ./tmux/tests/agent-attention.plugin.test.ts` (from `~/.config`) the plugin. The opt-in
  `bash ~/.config/tmux/tests/agent-attention.e2e.sh` starts a real opencode (MCP servers off) and makes
  one small model call; re-run it after upgrading opencode, since it proves the events still match.

## Three shortcut layers (the mental model)
| Layer | Keys | Job | Works |
|---|---|---|---|
| **Prefix** | `C-b <key>` | canonical — *every* action lives here | in tmux, **incl. SSH** |
| **CMD** | `Cmd+<key>` | local fast alias that replays a prefix action | local iTerm2 |
| **Shell** | `Ctrl+F` / `Ctrl+G` | file / grep finders (no tmux equivalent) | zsh prompt |

Rule: **`Cmd` = local one-chord, `C-b` = portable/SSH — same actions.** `Ctrl` is reserved for
shell finders (numbers are the one exception, see below). `Cmd` speaks *Mac* (`Cmd+T`=new), `C-b`
speaks *tmux* (`C-b c`=new) — different alphabets on purpose.

## Shell integration (`~/.config/zsh/rc.d/55-tmux.zsh`)
- **Auto-attach:** interactive local iTerm2 shells `exec tmux new-session -A -s main`, so you
  always land in tmux. Skipped inside tmux (no recursion) and when `NO_TMUX=1`.
- Detaching (`prefix d`) closes the tab (the exec'd tmux exited); open a new tab to come back.

## File layout (`~/.config/tmux/`)
```
tmux.conf               entry point: sources the rest
options.conf            behaviour: mouse, vi copy-mode, truecolor, escape-time, clipboard
keybindings.conf        prefix verbs (all -N described): s/v/h/j/k/l/H-L/m/q/o, c/,/n/b, f, N, ?
plugins.conf            TPM + plugin list + sessionx/floax/resurrect settings (runs TPM last)
theme.conf              tokyo-night-tmux options
nav-history.conf        back/forward history: hooks + prefix ←/→ (sourced after TPM)
agent-attention.conf    agent dot (status-right) + prefix ↑ + "seen" hooks (sourced last)
sessionizer.aliases     optional per-folder session-name overrides
scripts/sessionizer.sh  picker over ~/Projects (prefix f / Cmd+P)
scripts/session-here.sh new session from the current folder (prefix N)
scripts/new-window.sh   popup that names a new window (prefix c / Cmd+T)
scripts/rename-window.sh popup that renames the current window (prefix ,)
scripts/cheatsheet.sh   colorized prefix-key cheatsheet (prefix ?)
scripts/nav-history.sh  history logic: record (hooks) / back / forward (prefix ←/→)
scripts/agent-attention.sh  agent state: set (plugin) / seen (hooks) / next (prefix ↑)
tests/lib.sh            shared test harness: throwaway servers, fake opencode, assertions
tests/nav-history.test.sh  history tests, on throwaway tmux servers
tests/agent-attention.test.sh  agent dot + jump tests, on throwaway tmux servers
tests/agent-attention.plugin.test.ts  opencode plugin tests (bun)
tests/agent-attention.e2e.sh  opt-in end-to-end check with a real opencode
iterm2-cmd-layer.json   iTerm2 Dynamic Profile = the CMD layer
README.md               this file
```
The opencode half of the agent dot lives outside this folder:
`~/.config/opencode/plugins/agent-attention.ts`.

> **Picker display:** shows the **folder name only** (full path is in the preview + used for
> the session). **What the project finder lists:** children of `~/Projects` (add more via `SESSIONIZER_ROOTS`,
> or standalone dirs via `SESSIONIZER_EXTRAS`, space-separated). For a session from the folder
> you're *in*, use **`prefix N`**. For any dir you've merely visited, use **`prefix Tab`**
> (sessionx + zoxide). Inside `prefix Tab`: **`Ctrl-K`** kill · `Ctrl-R` rename · `Enter` switch.
>
> **Session naming:** named after the folder (only `.`/`:` sanitized, a leading dot stripped).
> Override a specific folder's name in `sessionizer.aliases` if you ever want to.

## Persistence behaviour
- **continuum** auto-saves every 15 min and **auto-restores on tmux start**.
- Quit iTerm2 → reopen → workspace returns (layout, cwd, nvim sessions).
- Over SSH: `prefix d` to detach; later `tmuxa <name>` (or `prefix Tab`) to reattach.
- Save state lives in `~/.local/share/tmux/resurrect/` (outside this repo).

## Dependencies
Present: `fzf`, `zoxide`, brew `bash` 5.3, `jq`, `bc`, `gdate`. The tests also use coreutils' `gsleep`
(as a fake opencode) and `bun` (plugin tests). **`status-right` only shows the agent dot.** `plugins.conf`
blanks the theme's widgets and `agent-attention.conf` puts the dot there, so the bar is the session name +
window tabs, plus `● N` while agents wait (`show_hostname` is `0` in `theme.conf`). To get the theme's
path / git widgets back, remove the `status-right` lines in both files; **battery / netspeed** additionally need:
```
brew install gawk gnu-sed
# then in theme.conf set the widget(s) to 1 and: prefix r
```

## Workflow model
**session = project · window = tab/task · pane = side-by-side view.** Switch *projects* with
`Cmd+P` / `prefix f` (open by folder) or `Cmd+O` / `prefix Tab` (switch among open); switch *tasks*
with `Ctrl+1-9` / `prefix n,b`. Don't nest tmux — keep sessions side by side and use the finder.

## iTerm2 CMD layer
CMD is invisible to nvim/tmux/zsh → 100% conflict-free. Delivered as a **Dynamic Profile**
(`iterm2-cmd-layer.json`, symlinked into `~/Library/Application Support/iTerm2/DynamicProfiles/`)
that inherits your default profile and only adds these `Send Hex Code` mappings (prefix `C-b`=`0x02`):

| Shortcut | tmux | Shortcut | tmux |
|---|---|---|---|
| `Cmd+T` | new window (prompts name) | `Cmd+I/J/K/L` | pane up/left/down/right |
| `Cmd+W` | kill pane | `Cmd+Return` | zoom pane |
| `Cmd+D` / `Cmd+Shift+D` | split side / stack | `Ctrl+1`…`9` | window 1–9 (Cmd+num = iTerm tabs) |
| `Cmd+Shift+[` / `]` | prev / next window | `Cmd+P` | project finder (open by folder) |
| `Cmd+/` | floating scratch | `Cmd+O` | session switcher (open sessions) |
| `Cmd+←` / `Cmd+→` | history back / forward | `Cmd+↑` | go to the agent waiting longest |

**Activate:** iTerm2 → Settings → Profiles → select **“tmux (CMD layer)”** → *Other Actions ▸
Set as Default*. **Rollback:** delete the symlink (or pick another profile). CMD bindings are
iTerm2-local — they don't travel over SSH; the `C-b` prefix is the portable fallback.
Notes: `Cmd+K` (normally clear buffer) becomes pane-down; `Cmd+C/V/F` are untouched.
`Cmd+←/→` (normally iTerm's previous/next tab, like `Cmd+Shift+[/]`) become history back/forward, and
`Cmd+↑` (normally iTerm scrolling one line, which does nothing useful under tmux) jumps to an agent.
The profile also sets **Left Option = Esc+** so nvim's `<M-…>` maps (e.g. `M-d`) reach nvim
through tmux (Right Option stays Normal, for accents). Paired with `extended-keys on` in tmux.

## Troubleshooting
- **Glyphs show as boxes** → set a Nerd Font in iTerm2 (Settings ▸ Profiles ▸ Text).
- **Cmd shortcuts do nothing** → activate the “tmux (CMD layer)” profile, then reopen iTerm2.
- **`Cmd+1-9` switches iTerm tabs, not tmux windows** → use `Ctrl+1-9` (by design — `Cmd+num` is iTerm's).
- **floax `C-M-…` resize keys** → use the `prefix P` menu (those are Ctrl+Meta combos; the menu is the reliable path).
- **nvim `<M-…>` keys don't reach nvim** → Option must send Meta as **Esc+**, not "Meta" (the CMD-layer profile sets Left Option = Esc+). Reopen iTerm2 after changing it.
- **A new-window popup didn't appear after editing config** → reload: `prefix r`.
- **`tmux-resurrect file not found` on the very first start** → benign; it seeds after the first save.
- **A plugin or menu looks broken** → reinstall plugins: `prefix I`.
- **`Cmd+←/→/↑` still switch iTerm tabs or scroll** → iTerm hasn't reloaded the CMD-layer profile: run
  `touch -h ~/Library/Application\ Support/iTerm2/DynamicProfiles/tmux-cmd-layer.json`, or reopen iTerm2
  (tmux and everything in it keep running).
- **An agent never shows in the dot** → that opencode started before the plugin was there (restart it), or an
  opencode upgrade changed its events (`oc` upgrades it daily). `bash ~/.config/tmux/tests/agent-attention.e2e.sh`
  tells which: it passes in the first case. To see what a pane reports: `tmux display -p -t <pane> '#{@agent_state}'`.

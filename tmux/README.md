# tmux configuration

A tmux config that **feels like nvim** (same window verbs), stays **invisible to nvim**
(zero keybinding conflicts), looks like **tokyonight-night**, and **persists sessions**
(detach / reattach / survive a terminal quit / reattach over SSH).

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
4. **iTerm2 CMD layer:** symlink the dynamic profile, then select it:
   ```sh
   mkdir -p ~/Library/Application\ Support/iTerm2/DynamicProfiles
   ln -sf ~/.config/tmux/iterm2-cmd-layer.json \
     ~/Library/Application\ Support/iTerm2/DynamicProfiles/tmux-cmd-layer.json
   ```
   iTerm2 → Settings → Profiles → **“tmux (CMD layer)”** → *Other Actions ▸ Set as Default* → reopen iTerm2.
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
| `prefix ,` | rename window |
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

### Floating & misc
| Keys | Action |
|---|---|
| `prefix p` / `prefix P` | floax floating scratch — toggle / menu |
| `prefix *` | native floating pane (tmux 3.7 ad-hoc; `p` is the daily scratch) |
| `prefix [` | copy mode (vi keys: `v` select, `y` copy) |
| `prefix ?` | **described cheatsheet** popup (`list-keys -N`, your real binds) |
| `prefix r` | reload config |

**Floating-pane controls (while the floax pane is open):** the title shows `C-M-s/b/f/r/e/d`
(Ctrl+**Meta**). macOS doesn't send Meta by default, so either use the **`prefix P` menu**
(plain keys: `-`/`+` size, `f` fullscreen, `r` reset, `e` embed) or set iTerm2 →
Profiles ▸ Keys ▸ **Right Option key = Esc+** to make `Ctrl+⌥(right)+s` etc. work.

### From the shell
- `Ctrl+F` → file finder · `Ctrl+G` → grep (your existing zsh finders; unchanged).
- Opening iTerm2 **auto-attaches** to a `main` session (see Shell integration). Opt out: `NO_TMUX=1`.
- Aliases (kept): `tmuxl` list · `tmuxa <name>` attach · `tmuxk <name>` kill

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
keybindings.conf        prefix verbs (all -N described): s/v/h/j/k/l/H-L/m/q/o, c/n/b, f, N, ?
plugins.conf            TPM + plugin list + sessionx/floax/resurrect settings (runs TPM last)
theme.conf              tokyo-night-tmux options
sessionizer.aliases     optional per-folder session-name overrides
scripts/sessionizer.sh  picker over ~/Projects (prefix f / Cmd+P)
scripts/session-here.sh new session from the current folder (prefix N)
scripts/new-window.sh   popup that names a new window (prefix c / Cmd+T)
iterm2-cmd-layer.json   iTerm2 Dynamic Profile = the CMD layer
README.md               this file
```

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
Present: `fzf`, `zoxide`, brew `bash` 5.3, `jq`, `bc`, `gdate`. Status widgets enabled:
**git, path, hostname**. To add **battery / netspeed** widgets later:
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

**Activate:** iTerm2 → Settings → Profiles → select **“tmux (CMD layer)”** → *Other Actions ▸
Set as Default*. **Rollback:** delete the symlink (or pick another profile). CMD bindings are
iTerm2-local — they don't travel over SSH; the `C-b` prefix is the portable fallback.
Notes: `Cmd+K` (normally clear buffer) becomes pane-down; `Cmd+C/V/F` are untouched.

## Troubleshooting
- **Glyphs show as boxes** → set a Nerd Font in iTerm2 (Settings ▸ Profiles ▸ Text).
- **Cmd shortcuts do nothing** → activate the “tmux (CMD layer)” profile, then reopen iTerm2.
- **`Cmd+1-9` switches iTerm tabs, not tmux windows** → use `Ctrl+1-9` (by design — `Cmd+num` is iTerm's).
- **floax `C-M-…` resize keys do nothing** → use the `prefix P` menu, or set iTerm2 Right Option = `Esc+`.
- **A new-window popup didn't appear after editing config** → reload: `prefix r`.
- **`tmux-resurrect file not found` on the very first start** → benign; it seeds after the first save.
- **A plugin or menu looks broken** → reinstall plugins: `prefix I`.

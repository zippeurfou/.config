# Eugene Yan — Working with AI (distilled)

Source: https://eugeneyan.com/writing/working-with-ai/ (May 2026).
Companion bootstrap: https://eugeneyan.com/assets/SETUP.txt.

These five principles drive the lean-root + lazy-guides pattern. Apply them
during audit and proposal phases.

## 1. Context as infrastructure

- Organize so the model can navigate via `grep` / `glob`. Keep a clean,
  predictable directory tree (`scripts/`, `data/`, `outputs/`, `docs/`, etc.).
- Per-project annotated `INDEX.md`. Each entry has the path + a one-paragraph
  "what's inside, when to read it". Saves the model from opening every link.
- Onboard each new session like a new hire: glossary for acronyms,
  project codenames, teammates with the same first name.
- Suggested reading order is gold. Tell the model: skim INDEX first, then
  TODOs, then specific topic notes.
- Memory layer split: `~/vault` (or per-project) holds *facts* (project state,
  artifacts, domain knowledge); `~/.claude` (or `~/.config/opencode/`) holds
  *configuration* (preferences, workflows, taste).

## 2. Taste as configuration

- Start with `~/.claude/CLAUDE.md` (or `~/.config/opencode/AGENTS.md`). It's
  a behavioral contract, not an instruction manual.
- Scope by directory: global → repo → project. Each layer owns its own taste.
- When a config gets too long, **split into lazy-loaded guides**. Don't
  `@import` — that just inlines them into every session. Instead, tell the
  config to read them when relevant.
- **Skills:** if you do something ≥ once a week, make it a skill. Keep
  `SKILL.md` small and focused on workflow + routing; put templates and
  scripts in separate files the model loads only when needed.
- **Bootstrap skills by doing the task once, then asking the model to make it
  a skill.** Refine via session transcript, not direct file edits.

## 3. Verification for autonomy

- Verification ladder: bottom = cheap and deterministic (post-edit hooks like
  `ruff format`); top = expensive and requires judgement (LLM review). Push
  every check to the lowest rung that catches it.
- Make verification feedback loops cheap so the model can self-correct: build
  the Docker image and read the error, render the dashboard and check tooltips,
  run the eval and read the metric.
- For long-running tasks, run a secondary "watcher" session with fresh context
  to check execution drift (doing the task right) and direction drift (doing
  the right task).

## 4. Scaling via delegation

- Pair-program for fast iteration; delegate when you can verify the result.
- Define success criteria and metrics first; then explain intent and
  constraints once and let the model execute end-to-end.
- Run sessions in parallel; the bottleneck shifts to spec-writing and review,
  not doing the work. Use git worktrees so parallel sessions don't clobber.
- Make sessions easy to observe: stop hooks (sound when done), tmux titles
  with status emoji, status line showing context usage.

## 5. Closing the loop

- Work in the open. Shared docs / repos / channels become future context for
  every agent (and human). Test: could a new teammate replicate last week's
  work from shared context only?
- **Mine your transcripts** for config gaps. Search past user turns for
  `actually`, `instead`, `don't`, `still wrong`, `can you also`, `did you
  check`. Each hit is a missing rule, missing verification step, or missing
  skill.
- Refactor and prune periodically. Each rule should live in exactly one place;
  conflicts make the model ignore both.

## Heuristic shortcuts

- First version of any config: 15-30 lines. Grow through use.
- "What would you tell a senior engineer joining the project on day one?" If
  they'd need it on day one, it probably belongs in AGENTS.md.
- If a linter / formatter / type-checker enforces it, it does **not** belong
  in AGENTS.md.
- LLMs reliably follow ~150-200 instructions. Every line in AGENTS.md
  competes for that budget on every session.

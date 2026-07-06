---
name: agents-config-hygiene
description: Audit a project's AGENTS.md and docs/ for the lean-root + lazy-guides pattern, propose targeted refactors, and proactively suggest extracting a new skill when the user reports doing the same multi-step task more than once. Use when entering a new project, when AGENTS.md exceeds ~150 lines or duplicates README, when no docs/INDEX.md exists, when the user mentions a recurring workflow ("I keep doing X by hand"), or when the user explicitly asks to set up / audit / refactor agent context for a repo.
license: Complete terms in LICENSE.txt
---

# Agents Config Hygiene

## Overview

Apply the lean-root + lazy-guides AGENTS.md pattern (derived from Eugene Yan's
*Working with AI* framework, tuned for Claude Opus 4.7) to any project. Audit
the current state, recommend the minimum useful changes, and execute approved
changes. Surface skill-extraction opportunities when the user reveals a
recurring workflow.

The full pattern, principle source, and Opus-4.7-specific levers live in
`references/`. Templates for the files this skill produces live in `assets/`.

## When this skill triggers

Match on any of these signals:

- **New project setup:** working directory has no `AGENTS.md` or no `docs/INDEX.md`.
- **Bloat:** `AGENTS.md` exceeds ~150 lines or visibly duplicates `README.md`.
- **Missing scaffolding:** no `docs/glossary.md`, no `docs/guides/`, no
  prohibitions / verification / acceptance-criteria blocks in `AGENTS.md`.
- **Recurring workflow signal:** user says "I keep doing X by hand", "every time
  I…", "should I make a script for…", or describes a multi-step task they have
  done at least once before.
- **Explicit ask:** "audit my AGENTS.md", "set up context for this repo",
  "clean up the docs", "make this opus-4.7 ready".

When a trigger fires, announce: *"I'm using the agents-config-hygiene skill to
audit and propose improvements."*

## Workflow

Three phases. Always assess before proposing; always propose before executing.

### Phase 1 — Assess (read-only)

Gather evidence in parallel; do not write yet.

1. List the repo root and `docs/` tree.
2. Read `AGENTS.md` (if present), `README.md`, and any `docs/INDEX.md` /
   `docs/glossary.md` / `docs/guides/*.md`.
3. Count lines in `AGENTS.md`; flag if >150.
4. Diff conceptually against `README.md`: identify content that appears in both
   (install, structure, commit conventions, stack list).
5. Diff conceptually against the user's personal `~/.config/opencode/AGENTS.md`:
   identify rules already covered globally.
6. Check for the eight pattern blocks (see `references/lean-root-template.md`):
   `<about_project>`, `<reading_order>`, `<workflow_overrides>`,
   `<verification>`, `<prohibitions>`, `<acceptance_criteria_template>`,
   `<mcp_triggers>`, `<lazy_guides>`. List which are missing.
7. List recent session transcripts under the repo (e.g., `session-ses_*.md`).
   Grep for correction phrases (`actually`, `instead`, `don't`, `still wrong`,
   `can you also`, `did you check`) and surface the top 3-5 patterns as
   candidate `<behavior>` rules or skill candidates.
8. Check for `CLAUDE.md`. If absent, flag the symlink-from-AGENTS.md option.

Output a short audit summary: line count, missing blocks, duplication overlap,
top transcript signals, and any skill-extraction candidates.

### Phase 2 — Propose

Present a tight, ranked list of changes — never a wholesale rewrite plan unless
the user asked for one. Each item: what, why, expected line delta. Group into:

- **Refactor AGENTS.md** (lean-root, dedupe, add missing blocks).
- **Create `docs/INDEX.md` + `docs/glossary.md` + `docs/guides/*`.**
- **Symlink `CLAUDE.md` → `AGENTS.md`** for cross-tool compatibility.
- **Extract a skill** for any recurring workflow surfaced in Phase 1. Use
  Eugene's heuristic: if the user does it ≥ once a week, make it a skill.
- **Add to personal `~/.config/opencode/AGENTS.md`** any rule that recurred
  across multiple projects (don't bury it in one project's file).

Use AskUserQuestion when there is a real choice (e.g., "extract `quarto-publish`
as a skill or leave as a guide?"). State your recommendation first.

If the user reports a recurring workflow and there is no existing skill for it:
**always recommend extracting a skill**, citing Eugene Yan's "do it once, then
make it a skill" heuristic. Reference `references/eugene-yan-principles.md`.

### Phase 3 — Execute (only after approval)

Use the templates in `assets/`:

- `assets/AGENTS.md.template` — root project AGENTS.md skeleton with all 8 blocks.
- `assets/INDEX.md.template` — annotated map for `docs/INDEX.md`.
- `assets/glossary.md.template` — vocabulary file skeleton.
- `assets/guide.md.template` — one-page guide skeleton with "Read when:" trigger.
- `assets/design-plan.md.template` — design doc for `docs/plans/YYYY-MM-DD-<topic>.md`.

Workflow per change:

1. Write a design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md` if the change
   touches more than one file. Capture the why, the file map, and what is
   intentionally out of scope.
2. Apply each change in a small, reviewable diff. Move content (don't lose it)
   from the bloated AGENTS.md into the appropriate `docs/guides/*.md`.
3. After every set of edits, run the project's verification commands (look in
   the user's existing AGENTS.md `<verification>` block, or ask).
4. For skill extraction: use the `skill-creator` skill (run its
   `init_skill.py` script) and bootstrap the SKILL.md from what the user
   already did. Never invent a skill from speculation — anchor it to a real
   task they completed.
5. Symlink `CLAUDE.md → AGENTS.md` in any location where the user runs
   Claude-flavored tooling (project root, `~/.config/opencode/`, etc.).

After execution, summarize: line counts before/after, files added, design doc
path, and the next two things you would suggest auditing later.

## Principles to enforce

These come from `references/eugene-yan-principles.md` and
`references/opus-4-7-levers.md`. Apply them; don't restate the source files.

- **Single source of truth.** Each rule lives in exactly one place. README owns
  human onboarding. Personal `AGENTS.md` owns global behavior. Project
  `AGENTS.md` owns project-specific overrides only.
- **Lazy-load over @-import.** Reference guides by path with a one-sentence
  trigger description. Never inline full guides into `AGENTS.md`.
- **Every rule traces to a source.** Correction in a transcript, repo evidence,
  or stated taste. Cut anything you can't justify.
- **Drop generic advice.** Frontier models default to "write tests for complex
  logic" and "use docstrings"; restating it costs tokens for zero signal.
- **Explicit prohibitions.** Use literal "Never X" bullets — Opus 4.7 follows
  them literally; soft suggestions get optimized away.
- **Acceptance criteria upfront.** Any task >5 minutes deserves a Goal / Inputs /
  Constraints / Done-when / Out-of-scope restatement before execution.
- **Bootstrap, don't speculate.** Skills come from real tasks the user just did.
  A skill built from speculation is worse than no skill.

## What to avoid

- **Don't propose a wholesale rewrite** when 2-3 targeted changes would do. The
  audit summary is the artifact most users actually need.
- **Don't extract a skill** from a workflow the user has done only once with no
  intent to repeat. Note it as a skill candidate and move on.
- **Don't edit `~/.config/opencode/AGENTS.md`** without explicit approval — it
  affects every session.
- **Don't write the new files in `data/`** or anywhere covered by `.gitignore` —
  these are version-controlled artifacts.
- **Don't claim the audit is "done"** without listing what was checked and what
  was deferred.

## References

Load these only when you need the underlying detail.

- `references/lean-root-template.md` — the eight pattern blocks, in order,
  with one-line descriptions.
- `references/eugene-yan-principles.md` — distilled framework: context as
  infrastructure, taste as configuration, verification for autonomy, scaling via
  delegation, closing the loop.
- `references/opus-4-7-levers.md` — model-specific tuning notes: literal
  following, effort levels, adaptive thinking, task budgets, tokenizer changes.

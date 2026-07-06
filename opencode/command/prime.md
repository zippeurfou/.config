---
description: "Prime the agent on the current codebase: read AGENTS.md, docs/INDEX.md, recent git log, and package manifest, then report a one-paragraph briefing of what this codebase is, the stack, key entry points, and recent focus. Do not start any work — wait for the user's actual prompt after the briefing."
---

Prime yourself on this codebase. Run these reads in parallel where possible (one tool message, multiple tool calls):

1. Read `AGENTS.md` (or `CLAUDE.md`) at repo root if either exists.
2. Read `docs/INDEX.md` if it exists; otherwise list the contents of `docs/` (top-level only).
3. Read `README.md` for the human-facing overview (first ~120 lines).
4. Run `git log --oneline -20` to see recent activity.
5. Read whichever package manifest is present: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`. If multiple, read all.
6. List repo root entries (`ls`).

Then produce a briefing in **exactly this format** (use these literal headers):

**Codebase**: <one paragraph: what this codebase is and what it does>

**Stack**: <languages, frameworks, package manager, notable infra>

**Key entry points**: <main scripts, commands, or modules an agent should know about — file:line references where useful>

**Recent focus** (last ~20 commits): <one sentence summarizing the trajectory>

**Where to load skills/guides**: <reference any docs/INDEX.md, docs/guides/*, or skills relevant to this repo; "no additional guides found" if absent>

**Open questions** (max 3): <things you'd want to clarify before any non-trivial work, or "none — ready when you are" if priming was complete>

**Strict rules:**
- Do NOT start any task. Do NOT write or edit files.
- Do NOT speculate about modules you didn't read.
- If a file doesn't exist, say so — don't fabricate.
- After the briefing, stop and wait for the user's actual prompt.

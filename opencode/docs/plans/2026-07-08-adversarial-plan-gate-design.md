# Adversarial Plan-Review Gate — Design

**Date:** 2026-07-08
**Status:** Approved, implementing
**Owner:** mferradou

## Problem

The current planning flow is `brainstorm → write-plan → present plan to me`.
Plans are presented before anyone has tried to break them. The most expensive
mistakes in recsys / eval / experiment work are wrong *load-bearing
assumptions* in the design — cheap to fix at the plan stage, days-expensive
once built. There is a `code-reviewer` subagent, but it only reviews *finished
code*; nothing pressure-tests a *plan before it is built*.

## Goal

Insert an automatic adversarial critique between "plan drafted" and "plan
presented to me", so every plan has already survived an attack by the time I
see it. The gate must be automatic (not something I remember to invoke) and
removable (in keeping with the thin-command-wrapper pattern this config uses).

Explicitly out of scope (considered and dropped): oracle advisor, librarian,
PR-shepherding loop, deploy-monitoring, swarm, beads, self-compaction. This
design is *only* the adversarial gate.

## The Loop

```
/brainstorm  →  design validated with me
     ↓
/write-plan  →  writing-plans drafts plan to docs/plans/*.md
     ↓
  [GATE] adversarial-reviewer critiques the plan file
     ↓
  auto-revise plan for valid findings (record why any finding is rejected)
     ↓
  present to me: revised plan + "what the critic caught & how I responded"
     ↓
  execution handoff (unchanged: subagent-driven or parallel session)
```

## Design Decisions

### 1. Adversarial-reviewer subagent (new)

- **File:** `agent/adversarial-reviewer.md`, registered in `opencode.json`
  under `agent` with `"prompt": "{file:./agent/adversarial-reviewer.md}"` —
  identical wiring to the existing `code-reviewer`.
- **Model:** `google-vertex-anthropic/claude-opus-4-8@default` (the user's
  default strong model), NOT `anthropic/claude-opus-4-8` (johnnymo87's naming).
- **Permissions:** pure critic. read/glob/grep/webfetch/websearch allow; all
  `git` mutations denied; write/edit/task/patch denied; `mcp-*` denied. Mirrors
  the `code-reviewer` lockdown so the reviewer can never mutate the tree.
- **Prompt body:** adapted from johnnymo87/workstation's adversarial-reviewer
  (steelman-then-attack; attack load-bearing assumptions not typos; rank by
  "how badly does this burn the user × likelihood"; cite `file:line`;
  distinguish verified vs suspected; grant what's actually right; verdict-first
  reporting). The body is excellent as-is; adopted with attribution here rather
  than rewritten.

### 2. Gate wiring — command layer, not plugin

**Chosen: patch the `write-plan.md` command** (and note it in the brainstorm
Phase-6 handoff path). Rejected alternative: a system-prompt-injecting plugin
(like johnnymo87's `subagent-routing.ts`).

Rationale: this config expresses workflow as thin command wrappers around
superpowers skills. The gate belongs in that same layer — simplest, most
removable, and it covers the real entry points (`/brainstorm`, `/write-plan`).
If plans later start slipping through other paths, promote to a plugin then.
YAGNI until then.

### 3. Gate strictness — auto-revise + summary

When the reviewer finds problems: incorporate the valid findings, revise the
plan file, then present the revised plan **with** a short "what the critic
caught & how I responded" note (including any finding deliberately rejected and
why). Fewest round-trips; I still see the full review and can overrule.

## Files Changed

| File | Change |
|------|--------|
| `agent/adversarial-reviewer.md` | new — subagent prompt body |
| `opencode.json` | new `agent.adversarial-reviewer` entry (mirrors code-reviewer) |
| `command/write-plan.md` | add the gate step after plan-save, before handoff |

## Verification

- `python -c "import json; json.load(open('opencode.json'))"` passes.
- `adversarial-reviewer` appears in the agent list.
- `/write-plan` instructs: save plan → dispatch adversarial-reviewer →
  auto-revise → present plan + critique summary → execution handoff.
```

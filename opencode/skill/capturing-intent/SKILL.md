---
name: capturing-intent
description: Use when a non-obvious technical or design decision is made that a future reader (or agent) could not reconstruct from the code alone - during brainstorming, planning, or mid-implementation. Records the *why* (context, alternatives, trade-offs) as a short versioned ADR next to the code, so intent survives after the plan is archived. Do not use for routine/obvious choices, or for the *how* (that belongs in a plan).
---

# Capturing Intent (Lightweight ADRs)

## Overview

Plans capture *how/what* and then get archived. Code captures *what is*. Neither
captures *why* - the forces, the constraints, the roads not taken. That gap is
**intent debt**: nobody can say why the system diverged from what you meant, or
when it happened. This skill closes it with one small, durable artifact per
decision.

**This is a flexible pattern, not a rigid workflow.** One ADR per meaningful
decision; skip the ceremony for obvious calls. This is deliberately *not*
OpenSpec - no proposal/design/specs/tasks quartet, just the one thing your
current loop is missing.

**Announce at start:** "I'm using the capturing-intent skill to record the decision and its rationale."

## When to write an ADR

Write one only when ALL three hold:

- The decision has a lasting structural or behavioral consequence.
- A competent reader could NOT infer *why* from the code and tests alone.
- You chose among real alternatives (there was an actual fork in the road).

Skip it when the choice is obvious, purely local, or trivially reversible.
Heuristic: if you'd re-explain it in a review, or you'd regret losing the
reasoning in six months, write it. Otherwise don't - noise buries signal.

## Where it lives

`docs/decisions/NNNN-short-title.md` - zero-padded sequential number. Commit it
**in the same commit/PR as the code it explains**, so it is versioned with the
code and reviewed with the code. This is the artifact to review for *intent*
(the "review intent, not just code" idea): it makes a PR's rationale auditable.

## The ADR (keep it under a page)

Copy `assets/adr-template.md`. Sections:

- **Title & Status** - `Proposed` / `Accepted` / `Superseded by NNNN`. Lead with the decision in the title.
- **Context** - the forces and constraints that make this a real decision; the *why-now*. This is the intent - spend your words here.
- **Decision** - what you chose, active voice ("We will...").
- **Alternatives considered** - the 2-3 rejected options, one line each on why they lost. Reuse the options you already generated in brainstorming.
- **Consequences / trade-offs** - what this makes easier, what it makes harder, what you are knowingly accepting.

## Integration with the existing loop

- **From brainstorming:** when Phase 2 (Exploration) settles on one approach over alternatives, that *is* an ADR - capture it here instead of letting the rationale evaporate into the design doc.
- **From writing-plans / execution:** if a task forces a non-obvious decision mid-implementation, pause, write the ADR, commit it with the change.

## Anti-patterns

- Don't restate the code ("we used a for loop"). Capture *why*, never *what*.
- Don't ADR everything - meaningful forks only.
- Don't edit an Accepted ADR to reverse it. Write a new one that supersedes it, so the history of intent is preserved.

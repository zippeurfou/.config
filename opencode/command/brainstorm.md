---
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores requirements and design before implementation."
---

Invoke the brainstorming skill and follow it exactly as presented to you.

## Planning handoff override

When you reach the brainstorming skill's Phase 6 (Planning Handoff) and create
the implementation plan with the writing-plans skill, you MUST also run the
adversarial gate from the `/write-plan` command: after the plan is saved and
before the Execution Handoff, dispatch the `adversarial-reviewer` subagent
against the plan, auto-revise for valid findings, and present the revised plan
plus a "what the critic caught & how I responded" summary. Do not present a
plan that has not been through this gate.

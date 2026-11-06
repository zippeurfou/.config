---
description: "Audit the codebase architecture for deepening opportunities (shallow modules, poor locality, leaky seams), present a visual HTML report, then grill through the chosen candidate. Deliberate architecture-health pass — run it periodically (e.g. one ticket per sprint). Wraps Matt Pocock's pristine skill with opencode adaptations."
---

Load Matt Pocock's `improve-codebase-architecture` skill with the native `skill`
tool and follow it exactly, starting at step 1 (Explore). It is registered
pristine (verbatim upstream) via `vendor-skills/`.

**OpenCode adaptations (apply these while following the skill — the skill text
is Pocock's Claude-oriented original; do not edit it, adapt at runtime):**

- **Explore step** → use the `task` tool with `subagent_type: "explore"` (the
  skill's `subagent_type=Explore`).
- **"Run the /codebase-design / /grilling / /domain-modeling skill"** → load it
  with the native `skill` tool (`codebase-design`, `grilling`,
  `domain-modeling` — all registered via `vendor-skills/`). Read
  `codebase-design`'s `DEEPENING.md` / `DESIGN-IT-TWICE.md` from the skill
  directory when it points you there.
- **Design-it-twice parallel sub-agents** → `task` tool, `subagent_type:
  "general"`, issued in parallel (one message, multiple calls).
- **ADRs** → the skill says `docs/adr/`; use **`docs/decisions/`** via your
  `capturing-intent` skill instead (your established convention). Read existing
  decisions there before proposing, and offer to record a rejected candidate as
  a `capturing-intent` ADR.
- **Domain language** → per-repo ubiquitous language lives in `CONTEXT.md` (keep
  Pocock's mechanism). For Grubhub company-wide acronyms/jargon, consult the
  `gdp-glossary` skill.
- **Refactor follow-through** (after the design is settled) → drive the
  deepening with obra's `test-driven-development` skill (red-green-refactor at
  the deepened module's interface) and close out with the `code-reviewer` agent.

Optional focus area (a directory, module, or concern to concentrate on):
$ARGUMENTS

If no focus area is given, review the repository as a whole.

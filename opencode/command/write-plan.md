---
description: Create detailed implementation plan with bite-sized tasks, then pressure-test it with the adversarial-reviewer before presenting
---

Invoke the writing-plans skill and follow it exactly as presented to you.

## Adversarial gate (mandatory, before presenting the plan to me)

After the plan is saved to `docs/plans/<filename>.md` and BEFORE the writing-plans
"Execution Handoff" step, run this loop:

1. **Dispatch the `adversarial-reviewer` subagent** (via the Task tool,
   `subagent_type: "adversarial-reviewer"`) against the saved plan file. Give it
   the plan path, the design doc / brainstorm context, and pointers to the code
   the plan will touch so it can verify claims against the real system.
2. **Auto-revise the plan** for the valid findings — incorporate the fixes
   directly into the plan file. For any finding you deliberately reject, record
   one line in the plan (or in your summary) saying why.
3. **Only then** present to me:
   - the revised plan, and
   - a short **"What the critic caught & how I responded"** summary: the
     ranked findings, which you fixed, and which you rejected (with reasoning).
4. Proceed to the writing-plans Execution Handoff as normal.

Do not present a plan that has not been through this gate.

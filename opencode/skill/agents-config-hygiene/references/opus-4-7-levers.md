# Claude Opus 4.7 — tuning levers that matter for AGENTS.md

Source: https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7

These are the model-specific behaviors that the lean-root + lazy-guides pattern
is tuned for. Use this list during audit to spot opportunities — e.g., a
`<verification>` block matters more on 4.7 because the model self-verifies
against acceptance criteria.

## Behaviors AGENTS.md should accommodate

### Literal instruction-following

- A plan with N acceptance criteria produces N checked items.
- Vague intent → vague output. Quantify everything that matters.
- Prefer explicit "Never X" prohibitions over softer guidance ("avoid X");
  the model treats prohibitions as hard constraints and suggestions as
  optimizations to deprioritize.

### Adaptive thinking

- Adaptive thinking is the *only* thinking mode in 4.7 (extended thinking
  budgets are gone — `thinking: {type: "enabled", budget_tokens: N}` returns
  400).
- Off by default. Enable explicitly via `thinking: {type: "adaptive"}` for
  intelligence-sensitive work.

### Effort levels (Messages API)

- Levels: `low` / `medium` / `high` / `xhigh` / `max`.
- Claude Code defaults to `xhigh` (between `high` and `max`).
- Most coding/agentic use cases: start at `xhigh`. Use minimum `high` for
  intelligence-sensitive work. Drop to `medium` only when speed/cost matters
  more than quality.
- AGENTS.md doesn't set effort, but you can mention preferred level in
  `<workflow_overrides>` when relevant.

### Task budgets (advisory)

- Beta header: `task-budgets-2026-03-13`. Minimum value: 20k tokens.
- The model sees a running countdown and self-prioritizes; distinct from
  `max_tokens` which is a hard per-request cap the model is **not** aware of.
- Use `task_budget` when you want self-moderation; use `max_tokens` to cap
  spend.
- Pair with stop criteria ("stop when tests pass") and fallbacks ("if you
  can't find X, return Y, don't guess") so end-of-budget doesn't become
  hallucination.

### Context window

- 1M token context window at standard pricing (no long-context premium).
- 128k max output tokens.
- Update `max_tokens` parameters for headroom; new tokenizer uses ~1-1.35x
  as many tokens as 4.6 (up to ~35% more, varying by content).

### Sub-agent behavior

- 4.7 spawns fewer sub-agents by default than 4.6.
- Anthropic guidance: do not spawn a sub-agent for work completable in a
  single response. Do spawn multiple sub-agents in the *same turn* when
  fanning out across independent items.
- For trusted long-running tasks: auto mode + `xhigh` effort.

### Removed knobs

- `temperature`, `top_p`, `top_k` set to non-default values return 400.
  Use prompting to guide behavior instead. Note: `temperature=0` never
  guaranteed identical outputs anyway.

## What this means for AGENTS.md

- `<acceptance_criteria_template>` is high-leverage on 4.7 — the model
  literally checks each item.
- `<prohibitions>` block pays off more than on 4.6.
- `<verification>` block with paste-output discipline mirrors 4.7's native
  self-verification behavior.
- Lean root + lazy guides is *especially* valuable given the 1M context: you
  *can* load everything, but the new tokenizer makes that 30% more expensive.
- Sub-agent dispatch in workflows: prefer single-turn fanout over multi-turn
  delegation chains.

# The eight pattern blocks for a project AGENTS.md

Use this list as a checklist during Phase 1 audit. Order in the file matches
the order here. Total target length: 80-120 lines for a project AGENTS.md,
60-90 lines for a personal/global one.

## 1. `<about_project>`

3-6 bullets. What this repo is, what stack additions exist on top of personal
defaults, layout summary. The minimum context a teammate would need on day one.

## 2. `<reading_order>`

Numbered list, ≤6 items. Tells the model what to read in what order, with the
last items being "only if asked". Stops the model from loading every doc up
front.

## 3. `<workflow_overrides>`

Bullets covering project-specific deviations from personal defaults. Examples:
"Python: uv only", "SQL: Confluence-first", "Docs: Quarto with GFM + HTML".
Do **not** restate global rules already in personal AGENTS.md.

## 4. `<verification>`

A fenced bash block of the exact commands the model must run before claiming
"done", with comments. Plus one sentence: "A claim of 'done' without evidence
of verification is a failure mode." Lean on the
`verification-before-completion` skill if available.

## 5. `<prohibitions>`

Literal "Never X" bullets. Examples: "Never commit anything in `data/`",
"Never push without explicit go-ahead", "Never invent table names". Opus 4.7's
literal-following makes these high-leverage.

## 6. `<acceptance_criteria_template>`

A 5-line template (Goal / Inputs / Constraints / Done-when / Out-of-scope) plus
one sentence: "If any field is unclear, ask one focused question rather than
guessing. Opus 4.7 is literal: vague criteria → vague results."

## 7. `<mcp_triggers>`

When-to-use one-liners for each MCP available in this project (Confluence,
GDP, Google, Slack, Datadog, etc.). Include a tiebreaker rule when two MCPs
would both work.

## 8. `<lazy_guides>`

Pointers to `docs/guides/*.md`, `docs/glossary.md`, `docs/plans/`, and any
project-level skills/agents under `.opencode/`. Each entry: relative path +
one-sentence "load when X" trigger description. **Never @-import** — that
defeats lazy loading.

## Personal global AGENTS.md variant

Personal `~/.config/opencode/AGENTS.md` swaps a few blocks:

- Replace `<about_project>` with `<about_me>` (role, default model, daily tools).
- Replace `<workflow_overrides>` with `<workflow_defaults>` (skills first,
  todos for 3+ steps, code-reviewer mandate, memory ask).
- Add `<context_retrieval_order>` (memory → repo → sub-agents → web).
- Add `<memory>` (ontology check process before writing).
- Add `<teaching>` (1-2 sentence format for unfamiliar terms).
- Drop `<acceptance_criteria_template>` (cover it in `<behavior>` instead) and
  `<mcp_triggers>` (project-specific) — keep them for project files.
- Keep `<prohibitions>` and `<lazy_loaded_guides>`.

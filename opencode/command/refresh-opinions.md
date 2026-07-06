---
description: "Refresh OPINIONS.md and VOICE.md from recent opencode activity. Distills durable new opinions and voice patterns from my own prompts since the last run, detects drift/contradictions against the current files, and asks before applying divergent changes. Combines refresh + drift watchdog in one pass."
---

You maintain Marc's `~/.config/opencode/OPINIONS.md` and `~/.config/opencode/VOICE.md` from his recent opencode prompt history. Goal: keep both files a faithful, durable map of what Marc believes and how he writes - fine-tuning and adding important patterns, never bloating with one-offs.

Argument: `$ARGUMENTS`
- empty -> incremental (process prompts since the last watermark)
- a number `N` -> look back N days (`--since-days N`)
- `all` -> full history (`--all`)
- `init` -> just set the watermark to now and stop (use once after a full backfill)

## Steps

1. **Extract new prompts.** Run the extractor and parse its JSON:
   - empty arg: `uv run ~/.config/opencode/scripts/opinions_extract.py`
   - number N: `uv run ~/.config/opencode/scripts/opinions_extract.py --since-days N`
   - `all`: `uv run ~/.config/opencode/scripts/opinions_extract.py --all`
   - `init`: `uv run ~/.config/opencode/scripts/opinions_extract.py --init` then STOP and report.
   If `status` is `initialized` or `n_new` is 0, report "no new activity" and STOP (nothing to do).

2. **Read inputs.** Read the `corpus_path` file (Marc's new prompts, each preceded by `--- [date] project ---`), then read the current `OPINIONS.md` and `VOICE.md` in full. If the corpus is large, skim for recurring patterns rather than reading every line - you want durable patterns, not a task log.

3. **Distill candidates.** From the new prompts, extract only DURABLE signals:
   - Opinions: beliefs, preferences, taste, recurring judgments about engineering, ML/recsys, tooling, agents, process, communication, leadership, product.
   - Voice: tone, structure, recurring phrasing, formatting habits, corrections of style.
   - IGNORE jokes, one-off task details, status/approval messages, and anything quoting or steelmanning someone else.
   - Treat technical detail as evidence of an underlying value, not content to copy (no implementation recipes).
   - Preserve uncertainty: a single weak signal is a "weak signal", not a belief.

4. **Drift check (watchdog).** Compare each candidate against the current files and classify:
   - NEW: a durable opinion/voice trait not yet captured.
   - REFINEMENT: sharpens or scopes an existing entry (prefer calling it a refinement unless old and new genuinely cannot both be true).
   - DIVERGENCE: contradicts an existing entry, or Marc now does the opposite of what a section says.

5. **Apply vs ask.**
   - NEW and clear REFINEMENTs that are consistent with the file -> integrate them directly (you may reorganize sections; the file is allowed to restructure, not just append).
   - DIVERGENCEs and anything ambiguous -> present them to Marc (old line + new evidence + why it diverges) and ASK whether to update, refine, or ignore. Use the question tool when interactive. If you are running non-interactively (no way to ask), apply only the safe NEW/REFINEMENT changes and list divergences in the summary for later review - never auto-resolve a contradiction.

6. **Edit the files** (OPINIONS.md and/or VOICE.md) honoring the invariants below.

7. **Advance the watermark** only after edits are saved: run the `mark_cmd` returned by step 1 (`uv run .../opinions_extract.py --mark <ts>`). If `init` or no changes, skip.

8. **Do NOT commit or push.** Show `git -C ~/.config diff --stat opencode/OPINIONS.md opencode/VOICE.md` and the full diff, then give Marc a copy-paste conventional-commit command (e.g. `git -C ~/.config add opencode/OPINIONS.md opencode/VOICE.md && git -C ~/.config commit -m "docs(opinions): refresh from recent activity"`). Let him run it.

## Invariants to preserve

- Format: one sentence per line; thematic `##`/`###` sections; concise prose, not bullets-of-bullets.
- Confidentiality: generalize all work specifics. Never write employee names, ticket IDs, internal metric values, dataset/table names, or business numbers into these files.
- Distinctive over table-stakes: keep the distinctive taste rich (how he runs agents, evaluation skepticism, people-leadership, "working = makes sense to a user"); keep industry table-stakes brief.
- Avoid absolutes: prefer "strong default" framing over "never/always" unless the evidence is overwhelming.
- Do NOT re-introduce previously removed points: (a) "calibrated probabilities over arbitrary scores", (b) "expensive tools should advertise their cost so the model self-selects".
- Keep these reconciliations intact: simplicity vs DRY = rule of three; autonomy vs control = autonomy within an approved plan, control at irreversible boundaries; code vs paper = papers inform/confirm ideas (bias to industry papers) but code and experiments decide once built; skills and MCP are different tools, not substitutes.

## Run summary (always output)

1. Sources + window checked, and `n_new` prompts processed.
2. Whether OPINIONS.md / VOICE.md changed (and a one-line description of each change).
3. Drift findings: for each, type (refinement/divergence), the existing claim/section, the new evidence, and the suggested action.
4. Whether the watermark was advanced.
5. The copy-paste git command (not executed).
If nothing changed and no drift: say exactly "No new durable opinions or voice changes, and no drift found."

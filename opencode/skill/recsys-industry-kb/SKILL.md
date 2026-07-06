---
name: recsys-industry-kb
description: >-
  Ground recommendation-systems work in RECENT INDUSTRY papers. Use when
  designing, brainstorming, debugging, or implementing any recsys / ranking /
  retrieval / personalization / CTR / embedding-retrieval / cold-start /
  sequential- or generative-recommendation ML-engineering task and you want to
  know what big-tech actually published recently, or to sanity-check an approach
  against real production systems. Backed by a local curated knowledge base
  (Netflix, Google, Meta, Alibaba, LinkedIn, ByteDance, Pinterest, etc.) built
  from arxiv_rec_finder. Complements — does not replace — the `papers` subagent:
  this is the industry-biased, always-fresh slice; fall back to `papers`/web for
  open-ended academic search or anything the corpus doesn't cover.
---

# recsys-industry-kb

A local, Obsidian-style knowledge base of recent **industry** recommendation-systems
papers. Each paper has a note (`papers/<arxiv_id>.md`) with a technical summary +
canonical `[[concept]]` links + resolvable references; concepts are cross-linked in
`concepts/<slug>.md`; `index.jsonl` is the searchable index.

**You (the agent) are the extraction engine** — there is no local LLM. The Python
builder does deterministic plumbing (fetch full text, cache, canonicalize, render,
index, commit); you read papers and produce the concept/technical-note content.

## Configuration

- Data repo (the KB): `$RECSYS_KB_DIR` (default `~/Projects/recsys-kb`).
- Builder (code): `~/Projects/arxiv_rec_finder` — run via `uv run --project`.
- Source issues repo: `zippeurfou/arxiv_rec_finder` (needs `GITHUB_TOKEN`).

Set once per session if needed: `export RECSYS_KB_DIR=~/Projects/recsys-kb`.

## The loop

Follow these steps (create TodoWrite items for a non-trivial request).

### 1. Refresh (once per work session, not every message)

```bash
git -C "$RECSYS_KB_DIR" pull --ff-only
uv run --project ~/Projects/arxiv_rec_finder python -m kb.build \
    --kb-dir "$RECSYS_KB_DIR" prepare --repo zippeurfou/arxiv_rec_finder \
    --incremental --recsys-only
```
(`--recsys-only` filters the discovery feed to papers with a recommendation-systems
signal, keeping off-domain LLM/vision/agent papers out of the KB.)

If `prepared=0`, skip to step 2. If `prepared>0`, do agent-driven extraction:

1. Read `$RECSYS_KB_DIR/.pending.jsonl` (one paper per line: `arxiv_id`, `title`,
   `companies`, `year`, `fulltext_path`, `references`).
2. For each paper, **read `fulltext_path`** and write one compact JSON line to
   `$RECSYS_KB_DIR/.extractions.jsonl` with:
   - `arxiv_id`
   - `concepts_raw`: generous, recall-biased list (~5–12 short noun phrases) of the
     techniques the paper ACTUALLY discusses. Prefer the canonical phrasings in
     `$RECSYS_KB_DIR/vocabulary.yaml` where they apply. Do not invent concepts.
   - `technical_note`: 3–5 sentences (problem / method / key result), specific
     (name the models/techniques and headline numbers). No preamble.
3. Ingest + commit:
   ```bash
   uv run --project ~/Projects/arxiv_rec_finder python -m kb.build \
       --kb-dir "$RECSYS_KB_DIR" ingest --extractions "$RECSYS_KB_DIR/.extractions.jsonl"
   git -C "$RECSYS_KB_DIR" pull --rebase   # integrate any concurrent push first
   git -C "$RECSYS_KB_DIR" push
   ```
   **Safe push — never `--force`.** If the push is rejected, or `pull --rebase`
   conflicts on the generated `index.jsonl` / `concepts/*.md`, run
   `git -C "$RECSYS_KB_DIR" rebase --abort`, then `git -C "$RECSYS_KB_DIR" pull`, and
   **re-run the `ingest` above** — it deterministically regenerates `index.jsonl` and
   the concept pages from `papers/`, so both sides' papers are preserved — then push.

> For many new papers, dispatch parallel subagents to do step 2 (one batch each),
> each appending to `.extractions.jsonl`.

### 2. Search (concept-first)

- By concept: read `$RECSYS_KB_DIR/concepts/<slug>.md` → it lists the papers.
  Browse `ls $RECSYS_KB_DIR/concepts/` for available concepts.
- By keyword / company / year / concept: grep the index, e.g.
  ```bash
  rg -i "cold-start|two-tower" "$RECSYS_KB_DIR/index.jsonl"
  rg '"companies": \[[^]]*Netflix' "$RECSYS_KB_DIR/index.jsonl"
  ```
- Read the shortlisted `papers/<arxiv_id>.md` notes to decide what's worth a deep read.

### 3. Read the full paper (bias toward reading)

The notes exist to help you CHOOSE; details live in the paper. When the task needs
specifics (architecture, losses, ablations, numbers), read the full text:

```bash
uv run --project ~/Projects/arxiv_rec_finder python -c \
  "from kb.acquire import get_fulltext; from pathlib import Path; \
   print(get_fulltext('<arxiv_id>', Path.home()/'.cache/recsys-kb/fulltext'))"
```

(Cache hit = instant; otherwise one polite arxiv2md fetch.)

### 4. Traverse citations (deep exploration)

A paper's `## References` list carries `(arXiv:<id>)` for many entries. To confirm or
go deeper, fetch a cited paper's full text with `get_fulltext('<cited_id>', ...)`. For
references without an inline id, resolve by title via the `papers` subagent or arXiv
search, then fetch.

### 5. Answer — grounded and cited

- Ground the recommendation in what these industry papers actually do.
- Cite specifically: paper title + `arXiv:<id>` (and issue # if useful).
- Bias toward RECENT, big-tech-authored work.
- State when you're extrapolating beyond the corpus.

## Manual add (a paper not from the issue feed)

The GitHub issues are only the *discovery* path; `ingest` and `canonicalize` never
touch GitHub, so any paper can be added by hand. Preferred flow (reuses `ingest`, so
the note is rendered in the exact standard format). Given an arXiv id:

1. **Fetch + cache full text** (skip if you already have the text):
   ```bash
   uv run --project ~/Projects/arxiv_rec_finder python -c \
     "from kb.acquire import get_fulltext; from pathlib import Path; \
      get_fulltext('<id>', Path.home()/'.cache/recsys-kb/fulltext')"
   ```
2. **Read the full text** and produce the extraction (same rules as refresh):
   `concepts_raw` (5–12 recall-biased phrases, prefer `vocabulary.yaml`) and a 3–5
   sentence `technical_note`. Get `title`/`year` from the paper (or arXiv), and
   `companies` from author affiliations (or `[]`).
3. **Write two one-line JSONL files** in `$RECSYS_KB_DIR` (keys must match exactly):
   - `.pending.jsonl` — metadata `ingest` reads:
     `{"arxiv_id":"<id>","title":"<title>","year":<yyyy>,"companies":["<Co>"],"url":"https://arxiv.org/abs/<id>","issue":null,"summary":"<1-3 sentences>","references":[]}`
   - `.extractions.jsonl` — your extraction:
     `{"arxiv_id":"<id>","concepts_raw":["..."],"technical_note":"..."}`
4. **Ingest + push** (renders `papers/<id>.md`, rebuilds `index.jsonl` + concept
   pages, commits):
   ```bash
   uv run --project ~/Projects/arxiv_rec_finder python -m kb.build \
       --kb-dir "$RECSYS_KB_DIR" ingest --extractions "$RECSYS_KB_DIR/.extractions.jsonl"
   git -C "$RECSYS_KB_DIR" pull --rebase && git -C "$RECSYS_KB_DIR" push
   ```
   (Same "safe push, never `--force`" recovery as the Refresh step: on reject/conflict,
   `rebase --abort`, `pull`, re-run `ingest`, push.)

Notes:
- `"issue": null` keeps the refresh watermark untouched, so a manual add never
  interferes with the automated pipeline; `ingest` overwrites idempotently if the
  same paper later arrives via an issue.
- `references` may be `[]`, or derive them: `from kb.refs import parse_references`.
- **Non-arXiv paper** (blog, internal doc): same flow with a stable id as the key;
  set the fields yourself and, to make the full text readable, drop its markdown at
  `~/.cache/recsys-kb/fulltext/<id>.md`.
- **New technique** not in `vocabulary.yaml`: add a slug/alias there and run
  `... canonicalize`, or it'll just surface in `unmapped_concepts.md`.

## Boundaries — grounded, not limited

This corpus is a **lens** (recent industry recsys), not a wall:
- It only contains big-tech-affiliated arXiv/Substack papers that `arxiv_rec_finder`
  flagged. Coverage gaps are expected.
- For open-ended academic search, older/foundational work, or non-industry papers,
  use the **`papers` subagent** and/or web search, and combine with this corpus.
- Some flagged papers are only loosely recsys (affiliation-matched); judge relevance.

## Checklist

- [ ] Refreshed this session (pull + incremental prepare/extract/ingest)
- [ ] Searched concepts + index; shortlisted papers
- [ ] Read the full text of the most relevant paper(s)
- [ ] Traversed key cited papers where detail mattered
- [ ] Answered with specific citations, biased to recent industry, gaps noted
- [ ] Used `papers`/web for anything outside the corpus

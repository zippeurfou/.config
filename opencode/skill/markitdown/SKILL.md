---
name: markitdown
description: Use when converting any non-Markdown file (PDF, Word/DOCX, PowerPoint/PPTX, Excel/XLSX, HTML, CSV, JSON, XML, EPub, Outlook .msg, ZIP), an image (OCR/EXIF), an audio file (transcription), or a YouTube URL into Markdown for reading, summarizing, or feeding into an LLM context window. Runs Microsoft's markitdown CLI via uvx (no install needed). Triggers include "convert this pdf", "what's in this docx", "extract the text", "transcribe this mp3", "ocr this image", "get the youtube transcript", or pre-processing a document for the papers subagent / RAG.
---

# markitdown

## Overview

`markitdown` (Microsoft) converts binary and structured documents into clean, token-efficient Markdown optimized for LLM consumption — preserving headings, lists, tables, and links. Run it with **`uvx`** so nothing needs to be installed persistently.

## The one command to remember

```bash
uvx --from 'markitdown[all]' markitdown <FILE> -o <OUTPUT.md>
```

**Always use `--from 'markitdown[all]'`.** The bare `uvx markitdown <file>` works ONLY for text formats (CSV/JSON/XML/HTML/plain text). For PDF, DOCX, PPTX, XLSX, audio, EPub, .msg, or YouTube it fails with `MissingDependencyException`. Using `[all]` avoids that failure entirely. uv caches the environment, so the first run downloads (~30s) and subsequent runs are fast.

## Quick reference

| Goal | Command |
|------|---------|
| Convert to a file | `uvx --from 'markitdown[all]' markitdown in.pdf -o out.md` |
| Convert to stdout (inspect) | `uvx --from 'markitdown[all]' markitdown in.docx` |
| Pipe / stdin (hint the type) | `cat in.pdf \| uvx --from 'markitdown[all]' markitdown -x pdf` |
| YouTube transcript | `uvx --from 'markitdown[all]' markitdown "https://youtu.be/<id>" -o transcript.md` |
| Keep base64 images inline | add `--keep-data-uris` |
| Use 3rd-party plugins | add `-p` (list them with `--list-plugins`) |

Flags: `-o` output file, `-x` extension hint (stdin), `-m` MIME hint, `-c` charset hint. Run `uvx --from 'markitdown[all]' markitdown --help` for the full list.

## Workflow

1. **Confirm the target.** Resolve to an absolute path; verify the file exists before converting.
2. **Convert** with the one command above. Use `-o` to write a `.md` file when the user wants it saved; omit `-o` to stream to stdout when they just want to read or you need the text in context.
3. **Report** the output path and a one-line summary. If streaming to terminal and the output is long (>~80 lines), save with `-o` and report the path instead of dumping it all.

## Format notes (only when relevant)

- **Audio transcription** uses local Whisper and is CPU-bound. Warn before transcribing anything long (e.g. a full podcast).
- **Image OCR**: the built-in converter reads only embedded EXIF text. For pixel-level OCR, use a plugin (`--list-plugins` to check) or Azure backends.
- **YouTube**: detected by the `http(s)://` prefix; pass the URL in quotes.
- **Untrusted input**: markitdown fetches URLs and reads files with the current process's privileges. Do not pass untrusted/attacker-controlled paths or URLs without sanitizing first.

## Azure backends (optional, only if asked)

Higher-fidelity cloud extraction for scanned PDFs, video, or structured field extraction:
- Document Intelligence: add `-d -e "<endpoint>"`
- Content Understanding: add `--use-cu --cu-endpoint "<endpoint>"`

These make billable Azure API calls — use only when the user explicitly requests them and provides an endpoint.

## Composing with other skills / subagents

markitdown is a pre-processor: turn a binary document into Markdown, then hand the text to whatever needs it.
- **papers subagent / research**: convert a downloaded paper PDF to Markdown, then pass the `.md` to the papers subagent or into context for summarizing/quoting — far more reliable than feeding raw PDF.
- **RAG / LLM context**: batch-convert source documents to `.md` for chunking and embedding.
- **xlsx / docx skills**: those skills create/edit Office files; markitdown goes the other direction (Office → Markdown) for quick reading or extraction.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `uvx markitdown file.pdf` → `MissingDependencyException` | Always include `--from 'markitdown[all]'`. |
| Falling back to `pip install markitdown` | Don't. Use `uvx`; it needs no install and no venv. |
| Dumping a multi-MB conversion to the terminal | Use `-o out.md` and report the path. |
| Forgetting `-x`/`-m` when piping via stdin | Provide a hint, e.g. `-x pdf`, so the type is detected. |

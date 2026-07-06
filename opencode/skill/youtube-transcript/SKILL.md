---
name: youtube-transcript
description: Fetch and clean transcripts from YouTube videos, channels, or playlists using yt-dlp. Use when the user asks to summarize, analyze, quote, or research a YouTube video, or wants to scan a creator's recent content for relevant material. Supports single-video transcripts (default = clean paragraph) and bulk channel/playlist scans (download N transcripts to a tmp dir for grep-based theme analysis instead of reading every transcript).
---

# YouTube Transcript

## Overview

Pulls auto-generated YouTube transcripts via `yt-dlp` and cleans them with a small Python script. Two workflows: single-video (direct quoting/summarization) and bulk channel/playlist scan (research a creator's content without loading every transcript into context).

## Prerequisites

- `yt-dlp` (verify: `yt-dlp --version`; install: `brew install yt-dlp`)
- `python3` (system python is fine; no extra packages needed)

The cleaner script lives at `~/.config/opencode/skill/youtube-transcript/scripts/clean_vtt.py`.

## Workflow 1: Single video

Use when the user gives a YouTube URL and wants the transcript, a summary, or specific quotes.

```bash
URL="https://www.youtube.com/watch?v=XXXXXXXXXXX"
mkdir -p /tmp/yt
yt-dlp --write-auto-subs --sub-langs en --skip-download \
  --convert-subs vtt \
  --output "/tmp/yt/%(id)s.%(ext)s" \
  --quiet --no-warnings \
  "$URL"

# Default: single clean paragraph (best for summarization)
python3 ~/.config/opencode/skill/youtube-transcript/scripts/clean_vtt.py /tmp/yt/*.en.vtt

# With timestamps (use only if user explicitly asks for them — for citations or jumping to moments)
python3 ~/.config/opencode/skill/youtube-transcript/scripts/clean_vtt.py --timestamps /tmp/yt/*.en.vtt
```

## Workflow 2: Bulk channel / playlist scan (grep-then-read)

Use when the user wants to research a creator's content, find videos relevant to a question across a channel/playlist, or extract themes without reading every transcript. Example trigger: *"What does <YouTuber> say about X?"* — when their channel has 20+ videos, this beats reading them all.

### Step 1 — List videos with metadata

```bash
yt-dlp --flat-playlist \
  --print "%(playlist_index)s | %(view_count)s | %(id)s | %(title)s" \
  --playlist-end 25 \
  "<CHANNEL_OR_PLAYLIST_URL>"
```

`--playlist-end N` caps the latest N. Use `--playlist-start M --playlist-end N` for a range. For a creator's `/videos` URL, this returns most-recent first.

### Step 2 — Bulk download transcripts

```bash
mkdir -p /tmp/yt-bulk
yt-dlp --write-auto-subs --sub-langs en --skip-download --convert-subs vtt \
  --output "/tmp/yt-bulk/%(playlist_index)02d-%(id)s.%(ext)s" \
  --playlist-end 25 --quiet --no-warnings \
  "<CHANNEL_OR_PLAYLIST_URL>"
```

Each transcript is ~5-15 KB. 25 transcripts ≈ 200 KB on disk.

### Step 3 — Clean all to plain text

```bash
cd /tmp/yt-bulk
for f in *.vtt; do
  python3 ~/.config/opencode/skill/youtube-transcript/scripts/clean_vtt.py "$f" \
    > "${f%.en.vtt}.txt"
done
```

### Step 4 — Theme-grep with TRUE occurrence counts

The cleaner produces single-line paragraphs (no embedded newlines). This means `grep -c` only returns 0 or 1 (line match, not occurrence count). **Always use `grep -oE | wc -l`** for real counts:

```bash
# Wrong — only counts 0/1 per file
grep -ciE "skill" *.txt

# Right — counts every occurrence
for f in *.txt; do
  hits=$(grep -oiE "\bskill[s]?\b" "$f" | wc -l | tr -d ' ')
  printf "%-40s %s\n" "$f" "$hits"
done | sort -t' ' -k2 -nr | head -10
```

For multi-theme ranking, build a small grep matrix (one column per theme):

```bash
for f in *.txt; do
  a=$(grep -oiE "skill"   "$f" | wc -l | tr -d ' ')
  b=$(grep -oiE "agent"   "$f" | wc -l | tr -d ' ')
  c=$(grep -oiE "hook"    "$f" | wc -l | tr -d ' ')
  printf "%-40s skill=%-3s agent=%-3s hook=%-3s tot=%s\n" \
    "$f" "$a" "$b" "$c" $((a+b+c))
done | sort -t= -k4 -nr | head -10
```

### Step 5 — Read top-K transcripts only

After ranking, read only the top 3-5 in full with the `read` tool. For long ones, wrap to 110 cols first so `grep -A/-B` context lines stay readable:

```bash
for id in <top-ids>; do
  fold -s -w 110 "${id}.txt" > "${id}.wrapped.txt"
done
```

Then targeted context-grep:

```bash
grep -niE "your|key|patterns" topfile.wrapped.txt | head -40
```

### Step 6 — Cleanup

```bash
rm -rf /tmp/yt-bulk
```

## Notes

- **YouTube bot challenges:** if `yt-dlp` returns "Sign in to confirm you're not a bot", run `brew upgrade yt-dlp` and retry. Avoid 100+ downloads in tight loops from one IP.
- **Rolling-caption duplication:** YouTube auto-subs repeat each line as it "rolls in"; the cleaner dedupes consecutive identical lines.
- **Bracketed cues** (`[Music]`, `[Applause]`) are stripped by default. Pass `--keep-brackets` to retain (matches the Steipete `video-transcript-downloader` default).
- **Auto-sub accuracy:** names, jargon, and code identifiers may be misspelled. When quoting verbatim, add a disclaimer or verify against the video.
- **No transcript exists** (some videos disable auto-subs): fall back to `--write-subs` for human-uploaded subs, or report to the user that no transcript is available.

## Why this skill exists

Built 2026-05-06 from the workflow that pulled 25 IndyDevDan videos (~157k words / ~210k tokens) to research opencode best practices in a single session. The reusable insight is the **bulk-then-grep workflow**, not the download primitive — for any channel research task at scale, downloading transcripts and grep-ranking them by theme is dramatically more token-efficient than reading every video.

## Comparison with existing skills (why we didn't use them)

- **steipete/video-transcript-downloader** (lobehub) — polished Node CLI wrapping `youtube-transcript-plus` + `yt-dlp` fallback. Requires `npm ci` and Node deps. Use this if you want non-YouTube support too.
- **intellectronica/youtube-transcript** (gist) — minimal zip-bundled skill. Opaque internals.
- **This skill** — zero new deps (uses `yt-dlp` you already have + system `python3`), transparent ~80-LOC cleaner, supports the bulk-then-grep research workflow as a first-class pattern.

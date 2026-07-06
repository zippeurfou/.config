#!/usr/bin/env python3
"""Clean YouTube VTT auto-subs into a flat paragraph transcript.

Strips:
- WEBVTT/Kind/Language/NOTE headers
- timestamp lines (00:00:00.000 --> ...)
- inline word-timing tags (<00:00:00.000><c> word</c>)
- blank lines
- consecutive duplicate lines (rolling-caption dedup)
- bracketed cues like [Music], [Applause] (default; --keep-brackets to keep)

Output:
- default: single paragraph (one space-joined line)
- --timestamps: one line per cue, prefixed [HH:MM:SS]

Usage:
    clean_vtt.py [--timestamps] [--keep-brackets] <in.vtt>
"""
import argparse
import re
import sys
from pathlib import Path

TIMESTAMP_LINE = re.compile(
    r"^(\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2}\.\d{3})"
)
INLINE_TAG = re.compile(r"<\d{2}:\d{2}:\d{2}\.\d{3}>|</?c>")
BRACKET_CUE = re.compile(r"\[[^\]]+\]")
HEADER_PREFIXES = ("WEBVTT", "Kind:", "Language:", "NOTE")


def clean(path: Path, *, keep_brackets: bool, timestamps: bool) -> str:
    text = path.read_text(encoding="utf-8", errors="ignore")
    out: list[str] = []
    last = ""
    current_ts = ""
    for line in text.splitlines():
        s = line.strip()
        if not s or any(s.startswith(p) for p in HEADER_PREFIXES):
            continue
        ts_match = TIMESTAMP_LINE.match(s)
        if ts_match:
            current_ts = ts_match.group(1)[:8]  # HH:MM:SS
            continue
        s = INLINE_TAG.sub("", s)
        if not keep_brackets:
            s = BRACKET_CUE.sub("", s)
        s = s.strip()
        if not s or s == last:
            continue
        if timestamps:
            out.append(f"[{current_ts}] {s}")
        else:
            out.append(s)
        last = s
    return "\n".join(out) if timestamps else " ".join(out)


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n", 1)[0] if __doc__ else None,
    )
    ap.add_argument("vtt_file", type=Path, help="Path to .vtt file")
    ap.add_argument(
        "--timestamps",
        action="store_true",
        help="Prepend [HH:MM:SS] to each line; output one line per cue",
    )
    ap.add_argument(
        "--keep-brackets",
        action="store_true",
        help="Keep bracketed cues like [Music], [Applause]",
    )
    args = ap.parse_args()
    if not args.vtt_file.exists():
        print(f"error: {args.vtt_file} not found", file=sys.stderr)
        sys.exit(2)
    print(
        clean(
            args.vtt_file,
            keep_brackets=args.keep_brackets,
            timestamps=args.timestamps,
        )
    )


if __name__ == "__main__":
    main()

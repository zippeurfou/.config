# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Incremental extractor of Marc's own prompts from the opencode SQLite DB.

Feeds the /refresh-opinions command: pulls genuine user-typed prompts created
since the last processed watermark, so OPINIONS.md / VOICE.md can be refreshed
from new activity only. stdlib only.

Usage:
  uv run opinions_extract.py                 # extract new prompts since watermark -> corpus file
  uv run opinions_extract.py --since-days 14 # override: look back N days
  uv run opinions_extract.py --all           # everything (full backfill)
  uv run opinions_extract.py --init          # set watermark to "now" without extracting
  uv run opinions_extract.py --mark <ts_ms>  # persist watermark (call after a successful refresh)

State (watermark) lives at ~/.local/state/opencode/opinions-state.json (NOT in the repo).
The corpus is written to a temp dir (raw prompts are never committed).
"""

import argparse, json, os, re, sqlite3, sys, tempfile, datetime

HOME = os.path.expanduser("~")
DB = os.environ.get("OPENCODE_DB") or os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")),
    "opencode/opencode.db",
)
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local/state")), "opencode"
)
STATE = os.path.join(STATE_DIR, "opinions-state.json")
WORK = os.path.join(tempfile.gettempdir(), "opencode_opinions_refresh")

MIN_LEN, MAX_LEN = 40, 4000
BUDGET = 400_000  # cap corpus bytes so the refreshing agent stays within context

SIGNAL = re.compile(
    r"(?ix)\b(prefer|instead|don't|do not|never|always|avoid|rather than|i like|i don't|"
    r"i hate|i want|i need|make sure|should not|shouldn't|no need|overkill|simpler|cleaner|"
    r"idiomatic|convention|best practice|why did you|you should|keep it simple|robust|"
    r"maintainab|scalab|co-author|em dash|lint|reproducib|stop|actually|let's not|that's wrong|"
    r"not what|i told you|please don't|too much|too complex|the right way|in my opinion|"
    r"i think|i believe|first principle|root cause|verify|evidence|dont)\b"
)


def now_ms():
    return int(datetime.datetime.now(datetime.UTC).timestamp() * 1000)


def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_state(d):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(d, f, indent=2)


def db():
    if not os.path.exists(DB):
        sys.exit(f"ERROR: opencode DB not found at {DB}")
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    return con


def max_ts(con):
    r = con.execute("SELECT MAX(time_created) AS m FROM message").fetchone()
    return int(r["m"] or 0)


def project_map(con):
    return {
        r["id"]: (r["worktree"] or "").replace(HOME + "/", "").split("/")[-1]
        or "global"
        for r in con.execute("SELECT id, worktree FROM project")
    }


def fetch(con, since_ts):
    pm = project_map(con)
    q = """
    SELECT m.time_created AS t, m.session_id AS sid, s.project_id AS pid, pt.data AS pdata
    FROM part pt
    JOIN message m ON m.id = pt.message_id
    JOIN session s ON s.id = m.session_id
    WHERE m.time_created > ?
      AND json_extract(m.data,'$.role')='user'
      AND json_extract(pt.data,'$.type')='text'
      AND IFNULL(json_extract(pt.data,'$.synthetic'),0)=0
    ORDER BY m.time_created ASC
    """
    rows = []
    for r in con.execute(q, (since_ts,)):
        try:
            txt = (json.loads(r["pdata"]).get("text", "") or "").strip()
        except Exception:
            continue
        if MIN_LEN <= len(txt) <= MAX_LEN:
            d = datetime.datetime.fromtimestamp(r["t"] / 1000, datetime.UTC).strftime(
                "%Y-%m-%d"
            )
            rows.append((r["t"], d, pm.get(r["pid"], "?"), txt))
    return rows


def evenspread(items, n):
    if n >= len(items):
        return list(items)
    if n <= 0:
        return []
    step = len(items) / n
    return [items[int(i * step)] for i in range(n)]


def fit(rows, budget):
    """Signal-weighted, time-spread down-sample so corpus bytes <= budget."""
    total = sum(len(r[3]) for r in rows)
    if total <= budget:
        return rows
    signal = [r for r in rows if SIGNAL.search(r[3])]
    others = [r for r in rows if not SIGNAL.search(r[3])]
    sig_bytes = sum(len(r[3]) for r in signal)
    if sig_bytes >= budget:
        chosen = evenspread(signal, max(1, int(len(signal) * budget / sig_bytes)))
    else:
        ob = budget - sig_bytes
        ot = sum(len(r[3]) for r in others) or 1
        chosen = signal + evenspread(others, max(0, int(len(others) * ob / ot)))
    chosen.sort(key=lambda r: r[0])
    return chosen


def write_corpus(rows):
    os.makedirs(WORK, exist_ok=True)
    path = os.path.join(WORK, "corpus.txt")
    with open(path, "w") as f:
        for _, d, proj, txt in rows:
            f.write(f"\n--- [{d}] {proj} ---\n{txt}\n")
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mark", type=int, help="persist watermark (ms) and exit")
    ap.add_argument("--init", action="store_true", help="set watermark to now and exit")
    ap.add_argument(
        "--since-days", type=int, help="look back N days instead of watermark"
    )
    ap.add_argument("--all", action="store_true", help="extract all history")
    args = ap.parse_args()

    con = db()

    if args.mark is not None:
        st = load_state()
        st["last_ts"] = args.mark
        st["last_run"] = now_ms()
        save_state(st)
        print(f"watermark set to {args.mark}")
        return

    if args.init:
        m = max_ts(con)
        save_state({"last_ts": m, "last_run": now_ms()})
        print(
            f"INITIALIZED watermark to current max ts {m} (future runs process only newer prompts)"
        )
        return

    st = load_state()
    cur_max = max_ts(con)
    if args.all:
        since = 0
        mode = "ALL history"
    elif args.since_days is not None:
        since = now_ms() - args.since_days * 86_400_000
        mode = f"last {args.since_days} days"
    elif "last_ts" in st:
        since = st["last_ts"]
        mode = "since watermark"
    else:
        # no state yet: default to nothing-new (OPINIONS.md already reflects full history)
        save_state({"last_ts": cur_max, "last_run": now_ms()})
        print(
            json.dumps(
                {
                    "status": "initialized",
                    "note": "No prior state; watermark set to now. Re-run with --since-days N to backfill a window.",
                    "new_watermark": cur_max,
                    "n_new": 0,
                },
                indent=2,
            )
        )
        return

    rows = fetch(con, since)
    sampled = fit(rows, BUDGET)
    path = write_corpus(sampled) if sampled else None

    print(
        json.dumps(
            {
                "status": "ok",
                "mode": mode,
                "db": DB,
                "n_new": len(rows),
                "n_sampled": len(sampled),
                "corpus_bytes": sum(len(r[3]) for r in sampled),
                "corpus_path": path,
                "new_watermark": cur_max,
                "mark_cmd": f"uv run {os.path.abspath(__file__)} --mark {cur_max}",
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()

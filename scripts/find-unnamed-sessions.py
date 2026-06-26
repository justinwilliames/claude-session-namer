#!/usr/bin/env python3
"""List substantive sessions that still lack a convention name, with a digest for
naming. This is the worklist for an on-demand LLM sweep (run by the live, already
authenticated assistant — no CLI login needed).

A session is a candidate when:
  - it has an index file (so it can actually be renamed), and
  - it is NOT the currently-active session ($CLAUDE_CODE_SESSION_ID), since the app
    clobbers external edits to the active session, and
  - it is a HUMAN session — its first substantive user message does NOT open with
    `<scheduled-task` (that prefix marks an automated cron/scheduled-task or self-
    resuming loop run, which we never rename — dated machine fires only clutter the
    sidebar), and
  - its transcript has >= 1 substantive user message (one-shot human sessions count).

Sessions whose title ALREADY matches `YYYY-MM-DD - Topic - Status` are NOT dropped —
they're emitted with `convention: true` and the parsed `cur_status` so the sweep can
re-derive the Status from the current outcome and rewrite ONLY if it has drifted
(Topic + date stay fixed). Un-named / mis-named sessions come through with
`convention: false`.

Outputs a JSON array to stdout: {uuid, proj, date, n, title, convention, cur_status,
first, last}.
Optionally pass --since-days N to limit to recently-active sessions.
"""
import json, glob, os, re, sys

ACTIVE = os.environ.get("CLAUDE_CODE_SESSION_ID", "")
CONVENTION = re.compile(r'^\d{4}-\d{2}-\d{2} - .+ - .+')
# An automated (non-human) session: cron/scheduled-task and self-resuming-loop runs
# all open their first user turn with this harness wrapper. Human sessions never do.
SCHEDULED = re.compile(r'^\s*<scheduled-task\b')
since_days = None
if "--since-days" in sys.argv:
    since_days = int(sys.argv[sys.argv.index("--since-days") + 1])

root = os.path.expanduser('~/Library/Application Support/Claude/claude-code-sessions')
index = {}   # cliSessionId -> (title, lastActivityAt)
for f in glob.glob(os.path.join(root, '**', 'local_*.json'), recursive=True):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    cli = d.get('cliSessionId')
    if cli:
        index[cli] = (d.get('title'), d.get('lastActivityAt', 0))

import time
now_ms = int(time.time() * 1000) if since_days else None


def digest(path):
    msgs, date = [], None
    for line in open(path, errors='ignore'):
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        if date is None and ev.get("timestamp"):
            date = ev["timestamp"][:10]
        if ev.get("type") != "user" or ev.get("isMeta") or ev.get("isCompactSummary"):
            continue
        c = ev.get("message", {}).get("content", "")
        if isinstance(c, list):
            if c and all(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
                continue
            c = " ".join(x.get("text", "").strip() for x in c if isinstance(x, dict) and x.get("type") == "text")
        c = (c or "").strip()
        if len(c) < 10 or c.startswith(("This session is being continued", "Summary:", "Base directory", "<system-reminder", "Caveat:")):
            continue
        msgs.append(re.sub(r"\s+", " ", c))
    return msgs, date


out = []
for f in glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')):
    uuid = os.path.basename(f)[:-6]
    if uuid == ACTIVE or uuid not in index:
        continue
    title, last = index[uuid]
    in_convention = bool(title and CONVENTION.match(title))
    # Status = the segment after the LAST " - " (Topic itself may contain " - ").
    cur_status = title.rsplit(" - ", 1)[1].strip() if in_convention else ""
    if since_days is not None and last and (now_ms - last) > since_days * 86400_000:
        continue
    msgs, date = digest(f)
    if len(msgs) < 1:
        continue
    if SCHEDULED.match(msgs[0]):   # automated scheduled-task / resumer-loop run — never rename
        continue
    out.append({
        "uuid": uuid,
        "proj": os.path.basename(os.path.dirname(f)),
        "date": date or "",
        "n": len(msgs),
        "title": title,
        "convention": in_convention,   # already named to convention → only re-check Status
        "cur_status": cur_status,      # parsed current Status, for drift comparison
        "first": msgs[0][:240],
        "last": msgs[-1][:140],
    })

out.sort(key=lambda r: r["date"], reverse=True)
print(json.dumps(out, indent=0))

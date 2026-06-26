#!/usr/bin/env bash
# generate-name-llm.sh — OPTIONAL LLM-grade session namer.
#
# Prints a single "YYYY-MM-DD - Topic - Status" line on success, nothing on any
# failure (missing CLI, not logged in, timeout, malformed output). The caller
# falls back to the deterministic heuristic (generate-name.py) when this is silent.
#
# Requires the `claude` CLI to be logged in (`claude /login` once in a terminal).
# Enable by exporting SESSION_NAMER_USE_LLM=1 for the hooks.
#
# Recursion-safe: sets SESSION_NAMER_INTERNAL=1 so the headless claude it spawns
# short-circuits this skill's own Stop/Start hooks instead of spawning again.

TRANSCRIPT="$1"
FALLBACK_DATE="${2:-$(date +%Y-%m-%d)}"
MODEL="${SESSION_NAMER_LLM_MODEL:-claude-haiku-4-5-20251001}"

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 1
command -v claude >/dev/null 2>&1 || exit 1

# Compact digest: session date + opening ask + final message.
DIGEST=$(python3 - "$TRANSCRIPT" "$FALLBACK_DATE" <<'PY'
import json, sys, re
path, fb = sys.argv[1], sys.argv[2]
msgs, date = [], None
def txt(ev):
    c = ev.get("message", {}).get("content", "")
    if isinstance(c, str): return c.strip()
    if isinstance(c, list):
        if c and all(isinstance(x, dict) and x.get("type") == "tool_result" for x in c): return ""
        return " ".join(x.get("text","").strip() for x in c if isinstance(x, dict) and x.get("type")=="text").strip()
    return ""
for line in open(path, errors="ignore"):
    line = line.strip()
    if not line: continue
    try: ev = json.loads(line)
    except Exception: continue
    if date is None and ev.get("timestamp"): date = ev["timestamp"][:10]
    if ev.get("type") != "user" or ev.get("isMeta") or ev.get("isCompactSummary"): continue
    t = txt(ev)
    if not t or len(t) < 10: continue
    if t.startswith(("This session is being continued","Summary:","Base directory","<system-reminder","Caveat:")): continue
    msgs.append(t)
if not msgs: sys.exit(1)
date = date or fb
first = re.sub(r"\s+", " ", msgs[0])[:500]
last = re.sub(r"\s+", " ", msgs[-1])[:300] if len(msgs) > 1 else ""
print(f"DATE: {date}\nOPENING ASK: {first}\nLAST MESSAGE: {last}")
PY
) || exit 1
[ -z "$DIGEST" ] && exit 1

read -r -d '' PROMPT <<EOF
You name Claude Code sessions in the exact format: YYYY-MM-DD - Topic - Status

Rules:
- Use the DATE given below verbatim.
- Topic: 2-4 words, Title Case, naming the THING worked on (system/artifact/question), not the action.
- Status: 2-4 words, Title Case, describing where the session ended (from LAST MESSAGE). E.g. Build Complete, Blocked On Export, Investigating Churn, Interrupted, Question Answered.
- Output ONLY the single name line. No preamble, no quotes, no markdown.

Session:
$DIGEST
EOF

NAME=$(SESSION_NAMER_INTERNAL=1 command claude -p --model "$MODEL" "$PROMPT" 2>/dev/null | tr -d '\r' | grep -m1 -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} - .+ - .+$')
[ -z "$NAME" ] && exit 1
echo "$NAME"

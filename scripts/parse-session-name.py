#!/usr/bin/env python3
"""Read a Claude Code transcript JSONL from stdin and extract the last
<!-- session-name: ... --> marker from the last assistant message."""
import sys, json, re

last_text = ""
for raw in sys.stdin:
    raw = raw.strip()
    if not raw or not raw.startswith("{"):
        continue
    try:
        ev = json.loads(raw)
    except Exception:
        continue
    if ev.get("type") != "assistant":
        continue
    for chunk in ev.get("message", {}).get("content", []):
        if chunk.get("type") == "text":
            text = chunk.get("text", "")
            if text:
                last_text = text

match = re.search(r"<!--\s*session-name:\s*(.+?)\s*-->", last_text)
if match:
    print(match.group(1).strip())

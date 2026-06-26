#!/usr/bin/env python3
"""Append a custom-title event to a Claude Code transcript JSONL.
This is the same mechanism the sidebar rename UI uses internally."""
import json, sys

transcript_path = sys.argv[1]
title = sys.argv[2].strip()
session_id = sys.argv[3]

event = json.dumps({
    "type": "custom-title",
    "customTitle": title,
    "sessionId": session_id
})

# Leading newline guards against appending onto a file whose last line lacks one;
# trailing newline keeps the next writer (ours or the app's) on a fresh line so
# we never produce concatenated `}{` records.
with open(transcript_path, "a") as f:
    f.write("\n" + event + "\n")

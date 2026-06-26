#!/usr/bin/env python3
"""Set a session's title in Claude Desktop's session index — the store the
sidebar actually reads.

Titles live in ~/Library/Application Support/Claude/claude-code-sessions/.../local_*.json
as a `title` field, keyed by `cliSessionId` (the transcript UUID). Appending a
`custom-title` event to the JSONL transcript does NOT drive the sidebar — that was
a long-standing misconception in this skill. This writes the real store.

Usage: set-index-title.py <cli_session_id> <title>
Prints the index file path on success; exit 1 if no index file matches.

NOTE: the app owns the *currently-loaded* session's title in memory and flushes it
to disk on quit, clobbering external edits. So this reliably renames CLOSED sessions
only. Do not expect it to stick for the active session.
"""
import json, glob, os, sys

cli = sys.argv[1]
title = sys.argv[2]
root = os.path.expanduser('~/Library/Application Support/Claude/claude-code-sessions')

for f in glob.glob(os.path.join(root, '**', 'local_*.json'), recursive=True):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    if d.get('cliSessionId') == cli:
        d['title'] = title
        d['titleSource'] = 'user'   # 'user' stops the app's auto-namer overriding it
        json.dump(d, open(f, 'w'), indent=2)
        print(f)
        sys.exit(0)

sys.exit(1)

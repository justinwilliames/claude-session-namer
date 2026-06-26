#!/usr/bin/env bash
# rename-session.sh — Rename a Claude Code session by appending a custom-title
# event to the session's transcript JSONL. This is exactly what the sidebar
# rename UI does internally — the Electron app watches the JSONL for changes
# and updates the sidebar immediately.
#
# Usage: rename-session.sh "New Title" <session-uuid>

set -e

NEW_TITLE="$1"
SESSION_UUID="$2"

if [ -z "$NEW_TITLE" ] || [ -z "$SESSION_UUID" ]; then
  echo "Usage: rename-session.sh 'New Title' <session-uuid>" >&2
  exit 1
fi

# Find the transcript JSONL (the file the Electron app actually watches)
TRANSCRIPT=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_UUID}.jsonl" 2>/dev/null | head -1)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Append a custom-title event — same format as the sidebar rename
python3 "$( dirname "$0" )/append-custom-title.py" "$TRANSCRIPT" "$NEW_TITLE" "$SESSION_UUID"

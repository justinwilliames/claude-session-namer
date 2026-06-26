#!/usr/bin/env bash
# rename-session.sh — Rename a Claude Desktop session by writing the title into
# the app's session index (the store the sidebar actually reads), keyed by the
# transcript UUID (cliSessionId).
#
# Usage: rename-session.sh "New Title" <cli-session-uuid>
#
# Replaces the previous approach of appending a `custom-title` event to the JSONL
# transcript — the app never read that, so it never worked. See set-index-title.py.
# Reliable for CLOSED sessions; the active session's title is owned by the app.

set -e

NEW_TITLE="$1"
CLI_SESSION_ID="$2"

if [ -z "$NEW_TITLE" ] || [ -z "$CLI_SESSION_ID" ]; then
  echo "Usage: rename-session.sh 'New Title' <cli-session-uuid>" >&2
  exit 1
fi

python3 "$(dirname "$0")/set-index-title.py" "$CLI_SESSION_ID" "$NEW_TITLE"

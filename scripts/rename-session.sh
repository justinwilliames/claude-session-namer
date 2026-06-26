#!/usr/bin/env bash
# rename-session.sh — Write a new title to a Claude Code session JSON file.
# Usage: rename-session.sh "New Title" <session-uuid>
#
# The session UUID is the cliSessionId field inside the local_*.json files at
# ~/Library/Application Support/Claude/claude-code-sessions/**/*.json
# Setting titleSource='user' mirrors what the sidebar rename does and locks
# the title against auto-overwrite by Claude Code's AI naming.

set -e

NEW_TITLE="$1"
SESSION_UUID="$2"

if [ -z "$NEW_TITLE" ] || [ -z "$SESSION_UUID" ]; then
  echo "Usage: rename-session.sh 'New Title' <session-uuid>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSIONS_DIR="$HOME/Library/Application Support/Claude/claude-code-sessions"

# Find the session file matching this cliSessionId
SESSION_FILE=$(grep -rl "\"cliSessionId\":\"$SESSION_UUID\"" "$SESSIONS_DIR" 2>/dev/null | head -1)

if [ -z "$SESSION_FILE" ]; then
  exit 0  # silent — session file not found (may be agent/subagent session)
fi

# Atomically patch title + titleSource
python3 "$SCRIPT_DIR/patch-session-json.py" "$SESSION_FILE" "$NEW_TITLE"

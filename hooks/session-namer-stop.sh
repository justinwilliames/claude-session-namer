#!/usr/bin/env bash
# session-namer-stop.sh — Stop hook.
# Reads the last assistant message from the transcript, parses the
# "**Session name:** `...`" line Claude outputs at the end of every turn,
# and writes it directly to the session's local JSON file — no UI needed.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENAME="$SCRIPT_DIR/../scripts/rename-session.sh"
PARSE="$SCRIPT_DIR/../scripts/parse-session-name.py"

# Read Stop event JSON from stdin (same pattern as caldwell stop-hook.sh)
EVENT_JSON=""
if [ ! -t 0 ]; then
  EVENT_JSON=$(timeout 2 cat 2>/dev/null || true)
fi

[ -z "$EVENT_JSON" ] && exit 0

# Extract transcript path
TRANSCRIPT_PATH=$(echo "$EVENT_JSON" | python3 "$SCRIPT_DIR/../scripts/extract-field.py" "transcript_path" 2>/dev/null || echo "")

[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# Extract session UUID from the transcript filename
SESSION_UUID=$(basename "$TRANSCRIPT_PATH" .jsonl)

[ -z "$SESSION_UUID" ] && exit 0

# Parse "**Session name:** `...`" from the last assistant message
SESSION_NAME=$(tail -c 100000 "$TRANSCRIPT_PATH" 2>/dev/null | python3 "$PARSE" 2>/dev/null || echo "")

[ -z "$SESSION_NAME" ] && exit 0

# Write it
"$RENAME" "$SESSION_NAME" "$SESSION_UUID" 2>/dev/null || true

exit 0

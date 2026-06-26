#!/usr/bin/env bash
# session-namer-start.sh — SessionStart hook.
# For existing sessions that already have content, write a custom-title to their
# JSONL (keyed by the exact session UUID) so the name is current for this and
# future loads. New sessions (< 2 user messages) are left alone — the Stop hook
# will name them after the first response. Like the Stop hook, this NEVER touches
# the sidebar by clicking, so it can never rename a different session.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GENERATE="$SCRIPT_DIR/../scripts/generate-name.py"
RENAME="$SCRIPT_DIR/../scripts/rename-session.sh"
LOG="/tmp/session-namer-debug.log"

SESSION_UUID="$CLAUDE_CODE_SESSION_ID"
[ -z "$SESSION_UUID" ] && exit 0

TRANSCRIPT=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_UUID}.jsonl" 2>/dev/null | head -1)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Only name if there's enough conversation to generate a meaningful name
MSG_COUNT=$(grep -c '"type":"user"' "$TRANSCRIPT" 2>/dev/null || echo 0)
[ "$MSG_COUNT" -lt 2 ] && exit 0

TODAY=$(date +%Y-%m-%d)
SESSION_NAME=$(python3 "$GENERATE" "$TRANSCRIPT" "$TODAY" 2>/dev/null || echo "")
[ -z "$SESSION_NAME" ] && exit 0

echo "$(date): start-hook name '$SESSION_NAME' uuid=$SESSION_UUID" >> "$LOG"
"$RENAME" "$SESSION_NAME" "$SESSION_UUID" >> "$LOG" 2>&1 || true

exit 0

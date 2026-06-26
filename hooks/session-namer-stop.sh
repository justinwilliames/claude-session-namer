#!/usr/bin/env bash
# session-namer-stop.sh — Stop hook.
# Uses CLAUDE_CODE_SESSION_ID env var (available in all Stop hooks) to locate
# the transcript and write the LLM-generated session name directly to the
# session JSON file — no UI, no stdin, no path encoding hacks.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENAME="$SCRIPT_DIR/../scripts/rename-session.sh"
PARSE="$SCRIPT_DIR/../scripts/parse-session-name.py"

SESSION_UUID="$CLAUDE_CODE_SESSION_ID"
[ -z "$SESSION_UUID" ] && exit 0

# Find the transcript by UUID — avoids needing to know Claude Code's
# exact project-key encoding (which handles spaces, tildes, etc.)
TRANSCRIPT=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_UUID}.jsonl" 2>/dev/null | head -1)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Parse "**Session name:** `...`" from the last assistant message
SESSION_NAME=$(tail -c 100000 "$TRANSCRIPT" 2>/dev/null | python3 "$PARSE" 2>/dev/null || echo "")
[ -z "$SESSION_NAME" ] && exit 0

# Write it
"$RENAME" "$SESSION_NAME" "$SESSION_UUID" 2>/dev/null || true

exit 0

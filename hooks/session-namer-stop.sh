#!/usr/bin/env bash
# session-namer-stop.sh — Stop hook.
# Generates a session name from transcript content (word-frequency heuristic) and
# appends a custom-title event to THIS session's JSONL, keyed by the exact session
# UUID the hook was handed. The Electron app picks the name up on the next load of
# this session. The name is NEVER applied by clicking the sidebar, so it can never
# rename a different session than the one that fired this hook.

# Recursion guard: if SESSION_NAMER_USE_LLM is on, this hook shells out to a
# headless `claude` that may fire its own Stop hook. That nested run sets
# SESSION_NAMER_INTERNAL=1, so we short-circuit here instead of spawning again.
[ -n "$SESSION_NAMER_INTERNAL" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENAME="$SCRIPT_DIR/../scripts/rename-session.sh"
GENERATE="$SCRIPT_DIR/../scripts/generate-name.py"
GENERATE_LLM="$SCRIPT_DIR/../scripts/generate-name-llm.sh"
LOG="/tmp/session-namer-debug.log"

echo "$(date): fired uuid=$CLAUDE_CODE_SESSION_ID" >> "$LOG"

SESSION_UUID="$CLAUDE_CODE_SESSION_ID"
[ -z "$SESSION_UUID" ] && echo "$(date): EXIT no uuid" >> "$LOG" && exit 0

TRANSCRIPT=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_UUID}.jsonl" 2>/dev/null | head -1)
echo "$(date): transcript=$TRANSCRIPT" >> "$LOG"
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && echo "$(date): EXIT no transcript" >> "$LOG" && exit 0

TODAY=$(date +%Y-%m-%d)
# Prefer LLM-grade naming when opted in (needs `claude /login`); fall back to the
# deterministic heuristic on any failure so naming never silently stops.
SESSION_NAME=""
[ "$SESSION_NAMER_USE_LLM" = "1" ] && SESSION_NAME=$(bash "$GENERATE_LLM" "$TRANSCRIPT" "$TODAY" 2>/dev/null || echo "")
[ -z "$SESSION_NAME" ] && SESSION_NAME=$(python3 "$GENERATE" "$TRANSCRIPT" "$TODAY" 2>/dev/null || echo "")
echo "$(date): name='$SESSION_NAME'" >> "$LOG"
[ -z "$SESSION_NAME" ] && echo "$(date): EXIT no name" >> "$LOG" && exit 0

# Debounce: skip if the generated name hasn't changed from last custom-title
LAST_TITLE=$(python3 -c "
import json
last = ''
for line in open('$TRANSCRIPT'):
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except Exception:
        continue
    if ev.get('type') == 'custom-title':
        last = ev.get('customTitle', '')
print(last)
" 2>/dev/null)

SESSION_NAME_LC=$(echo "$SESSION_NAME" | tr '[:upper:]' '[:lower:]')
LAST_TITLE_LC=$(echo "$LAST_TITLE" | tr '[:upper:]' '[:lower:]')

if [ "$SESSION_NAME_LC" = "$LAST_TITLE_LC" ]; then
    echo "$(date): name unchanged, skip" >> "$LOG"
    exit 0
fi

# Append custom-title to this session's JSONL, keyed by its UUID (applied on next load).
echo "$(date): appending to jsonl" >> "$LOG"
"$RENAME" "$SESSION_NAME" "$SESSION_UUID" >> "$LOG" 2>&1 || true

echo "$(date): done" >> "$LOG"
exit 0

#!/usr/bin/env bash
# session-namer-start.sh — SessionStart hook.
# Injects additionalContext telling Claude to output a contextual session name
# at the END of every response in the format: YYYY-MM-DD - Topic - Status

TODAY=$(date +%Y-%m-%d)

DIRECTIVE="SESSION NAMING — At the END of every assistant response this session, output a single line with a suggested session name:

**Session name:** \`${TODAY} - <Topic> - <Status>\`

Rules:
- Topic: 2–5 words, Title Case — name the thing being worked on (system, project, or task), not the action
- Status: 2–6 words, Title Case, LLM-generated — describe precisely what is happening RIGHT NOW based on the work just done or discussed. This is freeform, not a fixed list. Examples: 'Wiring Stop Hook', 'Debugging JSON Output', 'Done - Skill Deployed', 'Planning Naming Convention', 'Investigating Customer Churn', 'Canvas QA Complete'
- Output this as the very LAST line of your response, after all other content
- Keep updating it every turn — the Status should reflect the current state of work, not where the session started
- The user renames the session manually by clicking the title in the sidebar
- If context is thin on the first turn, make the best inference — don't ask"

printf '%s' "$DIRECTIVE" | python3 -c 'import json,sys
ctx = sys.stdin.read()
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx
    }
}))'

exit 0

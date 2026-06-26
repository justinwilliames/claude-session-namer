---
name: session-namer
description: >
  Generate or refresh a session name in the format YYYY-MM-DD - Topic - Status.
  Invoke when the user wants to name or rename the current Claude Code session,
  update the session name as work progresses, or needs a name to paste into the
  session title field. Triggers on: "name this session", "update the session name",
  "what should I call this chat", "session name", "/session-namer".
  Fires automatically via Stop hook (every response) and SessionStart hook (on session load).
---

# Session Namer

## System requirements

- **Python 3** (standard library only — no Pillow, no network, no LLM call)
- Both hooks registered in `~/.claude/settings.json` (stop timeout 30s, start timeout 15s)

The hooks work fully automatically and have **no external dependencies**. Naming is applied
purely by writing a `custom-title` event into the session's own JSONL, keyed by the exact
session UUID. The Electron app reads that title when the session next loads.

## How the automatic naming works

Both hooks identify the session by `CLAUDE_CODE_SESSION_ID` — the exact UUID the hook is
handed — and only ever touch *that* session's JSONL. They never click the sidebar, so they
can never rename a different session than the one that fired. (Earlier versions drove the
sidebar via a screenshot + cliclick, which renamed whichever row happened to be highlighted
on screen — frequently the wrong session. That path was removed.)

**Stop hook** (`session-namer-stop.sh`) fires after every assistant response:
1. Reads all user messages from the session JSONL
2. Generates a name via word-frequency heuristic (`generate-name.py`) — no LLM call, no network
3. Debounces: skips if the name hasn't changed since the last `custom-title`
4. Appends a `custom-title` event to the JSONL, keyed by the session UUID (`rename-session.sh`)

**Start hook** (`session-namer-start.sh`) fires when a session loads:
- Same generation + JSONL write, keyed by the session UUID
- Only runs if the session has ≥ 2 user messages (skips brand-new sessions)

## Where the name shows up

The sidebar reflects the new name when the session is **next loaded** (reopened, or after an
app restart) — the running app does not pick up appended `custom-title` events live. This is
the deliberate trade for correctness: deterministic UUID-keyed writes can never clobber a
different session, whereas the old live-update path could and did.

---

Generate a session name in the standard format:

`YYYY-MM-DD - <Topic> - <Status>`

## On invocation

1. Run `date +%Y-%m-%d` to get today's date
2. Infer the **Topic** from the conversation (what work is being done, which system/project)
3. Determine the **Status** from the table below based on current progress
4. Output the suggested name prominently on its own line as inline code
5. Remind the user to rename the session by clicking the title in the sidebar

## Topic naming — rules

- 2–5 words, Title Case
- Name the *thing being worked on*, not the action
- Be specific enough that the session is identifiable in a list of 20

| What's happening | Topic |
|---|---|
| Building or editing a Braze activation canvas | Activation Canvas |
| Debugging a PostHog event | PostHog Event Bug |
| Writing lifecycle email copy | Lifecycle Email Copy |
| Setting up a Hightouch sync | Hightouch Sync Setup |
| Auditing HubSpot properties | HubSpot Audit |
| Creating a new Orbit skill | Orbit Skill - session-namer |
| Investigating a customer issue | Customer - <Name/ID> |
| General data investigation | Data Investigation |
| Setting up infrastructure | Infra Setup |
| Reviewing a PR or diff | PR Review - <description> |

## Status — LLM-generated, freeform, Title Case

The Status is not a fixed vocabulary. It is a precise 2–6 word Title Case description of what is happening right now, generated from the actual conversation context.

Examples of good statuses:
- `Wiring Stop Hook`
- `Debugging JSON Output`
- `Done - Skill Deployed`
- `Planning Naming Convention`
- `Investigating Customer Churn`
- `Canvas QA Complete`
- `Fixing Liquid Syntax Error`
- `Reviewing PR Diff`
- `Blocked on Stripo Export`
- `Writing Activation Copy`

The Status should update every turn to reflect the current state, not where the session started.

## Output format

Always output the name as a standalone line like this:

**Suggested session name:** `2026-06-26 - Activation Canvas - Building`

*Rename: click the session title in the sidebar → paste.*

## On re-invocation mid-session

Output a fresh name with an updated Status reflecting current progress.
Keep the same Topic unless the work has clearly pivoted to something different.
The Status is always freeform — generate it from what's actually happening, not from a list.

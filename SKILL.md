---
name: session-namer
description: >
  Generate or refresh Claude Desktop session names in the format
  YYYY-MM-DD - Topic - Status, and apply them to the sidebar by writing the app's
  session index. Invoke when the user wants to name/rename a session or "tidy my
  sessions" — sweep the backlog of un-named sessions into the convention. Triggers on:
  "name this session", "rename my sessions", "tidy my sessions", "what should I call
  this chat", "session name", "/session-namer".
---

# Session Namer

## How Claude Desktop stores session titles (load-bearing)

Session titles live in the **app's own session index**, NOT in the transcript:

```
~/Library/Application Support/Claude/claude-code-sessions/<workspace>/<…>/local_*.json
```

Each index file has a `title` and `titleSource` field and a `cliSessionId` that equals
the transcript UUID. `titleSource: "user"` tells the app's built-in auto-namer to leave
the title alone. **Appending a `custom-title` event to the JSONL transcript does nothing**
— the sidebar never reads it (a long-standing misconception now corrected).

Two hard constraints discovered the hard way:

1. **The app owns the *active/loaded* session's title in memory and flushes it to disk on
   quit**, clobbering any external edit. So writing the index file reliably renames **closed**
   sessions; it will NOT stick for the session you are currently in, or for pinned/loaded ones.
   The active session is named by the app's own auto-namer (which is decent) or a manual UI
   rename.
2. **The running app only reads the index on launch.** New titles appear after a relaunch /
   reopen, not live.

## How naming works now (on-demand, live-LLM)

There are **no hooks**. Per-turn hook naming was retired because (a) it can't beat the app for
the active session, and (b) a heuristic running in a logged-out subprocess would *downgrade*
the app's own auto-names. Instead:

- **The live, already-authenticated assistant does the naming.** When the user asks to name or
  "tidy" sessions, the assistant generates proper `YYYY-MM-DD - Topic - Status` names (full
  conversation context, no CLI login, no extra cost) and writes them to the index store via
  `rename-session.sh "<title>" <cliSessionId>` (→ `set-index-title.py`).
- **Worklist:** `find-unnamed-sessions.py` lists substantive **closed** sessions whose index
  title doesn't yet match the convention (excludes the active session and no-index sessions),
  with a digest (opening ask + last message) for each. That's the sweep input.
- **`generate-name.py`** is a deterministic heuristic fallback (first-message-anchored topic,
  last-message status, session's own date) for unattended/scheduled sweeps where no live model
  is in the loop.

After a sweep, the names appear on the next Claude Desktop relaunch.

## Sweep recipe

1. `find-unnamed-sessions.py > /tmp/unnamed.json` (optionally `--since-days N`).
2. For each entry, generate a `YYYY-MM-DD - Topic - Status` name from its digest (live assistant
   = best quality; or `generate-name.py <transcript>` for the heuristic floor).
3. Apply: `rename-session.sh "<name>" <uuid>` per session.
4. Tell the user to relaunch Desktop to see them.

---

Generate a session name in the standard format:

`YYYY-MM-DD - <Topic> - <Status>`

## On invocation

1. Use the session's own date (`YYYY-MM-DD` from its first transcript event), not necessarily today
2. Infer the **Topic** from the conversation (what work is being done, which system/project)
3. Determine the **Status** from the table below based on current progress
4. Output the suggested name on its own line as inline code
5. **Apply it** via `rename-session.sh "<name>" <cliSessionId>` for closed sessions. For the
   *current* session, the app owns the title — offer the name for a manual UI rename instead,
   since a disk write won't stick while it's active.

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

For closed sessions the skill applies it directly to the index store. For the active session,
the user renames via the sidebar (right-click → Rename → paste) — the app owns the live title.

## On re-invocation mid-session

Output a fresh name with an updated Status reflecting current progress.
Keep the same Topic unless the work has clearly pivoted to something different.
The Status is always freeform — generate it from what's actually happening, not from a list.

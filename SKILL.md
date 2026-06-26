---
name: session-namer
description: >
  Generate or refresh session names in the format YYYY-MM-DD - Topic - Status across
  BOTH stores: local Claude Desktop sessions (write the app's index) AND claude.ai/code
  cloud sessions (rename via Claude in Chrome). Invoke when the user wants to name/rename
  a session or "tidy my sessions" — a full sweep does desktop first, then cloud. Also
  re-checks already-named sessions and refreshes a drifted Status. Triggers on: "name this
  session", "rename my sessions", "tidy my sessions", "what should I call this chat",
  "session name", "rename my cloud/claude.ai sessions", "/session-namer".
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

**Local Desktop only — cloud sessions are out of reach.** This index holds only local Desktop
sessions, keyed by `cliSessionId` == a **UUIDv4**. A URL of the form
`claude.ai/code/session_01…` is a **cloud** session — that `session_01…` ULID is server-side
and appears in NO local index file. So `find-unnamed-sessions.py` never lists them and
`set-index-title.py` cannot rename them; there is no first-party path from this toolchain to
claude.ai. If the user pastes `claude.ai/code` links asking why they aren't renamed: wrong
store, by design. Cloud titles are set by claude.ai's own auto-namer — rename in the web UI or
drive claude.ai via Claude-in-Chrome.

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
- **Worklist:** `find-unnamed-sessions.py` lists **human closed** sessions (excludes the active
  session and no-index sessions), with a digest (opening ask + last message) for each. That's
  the sweep input. **Every human session counts, including one-shots** (`>= 1` substantive user
  turn) — a single-ask session still deserves a dated, descriptive name. **Automated runs are
  excluded:** any session whose first user turn opens with `<scheduled-task` is a cron/scheduled-
  task or self-resuming-loop fire (e.g. `Infinite working skill resumer`, `Command centre poll`,
  the LinkedIn/calendar/inbox routines) — dating those just clutters the sidebar with near-
  duplicates, so they're never renamed.
- **Convention-named sessions are NOT skipped — re-check their Status.** The worklist now emits
  already-convention sessions too, flagged `convention: true` with the parsed `cur_status`. For
  these, re-derive the Status from the current final outcome and rewrite ONLY if it has drifted
  (e.g. a session named `… - Mid Build` that actually shipped becomes `… - Done`). **Date and
  Topic stay frozen** — only the Status moves. If the re-derived Status matches `cur_status`,
  skip the write. Sessions with `convention: false` get a full fresh name.
- **`generate-name.py`** is a deterministic heuristic fallback (first-message-anchored topic,
  last-message status, session's own date) for unattended/scheduled sweeps where no live model
  is in the loop.

After a sweep, the names appear on the next Claude Desktop relaunch.

## Sweep recipe — two phases, ALWAYS in this order

`/session-namer` (no args, or "tidy my sessions") runs **Phase 1 first to completion, THEN
Phase 2**. Local desktop is cheap and reliable; cloud is the slow browser-driven arm — never
start cloud until desktop is done. A targeted invocation ("name THIS session") skips the sweep
and just names the one session.

### Phase 1 — Desktop sessions (local index)

1. `find-unnamed-sessions.py > /tmp/unnamed.json` (optionally `--since-days N`).
2. For each entry:
   - `convention: false` → generate a full `YYYY-MM-DD - Topic - Status` name from its digest
     (live assistant = best quality; `generate-name.py <transcript>` is the heuristic floor).
   - `convention: true` → re-derive **only the Status** from the last turn; if it differs from
     `cur_status`, rebuild the title with the SAME date + Topic and the new Status. If unchanged,
     skip.
3. Apply each: `rename-session.sh "<name>" <uuid>`.
4. Tell the user desktop names appear on the next Claude Desktop relaunch.

### Phase 2 — Cloud sessions (claude.ai/code, via Claude in Chrome)

These are `claude.ai/code/session_01…` (ULID) sessions — a **separate store** the local index
cannot touch (see the SCOPE note above). **No bulk path exists — drive the UI** (verified
2026-06-26):
- The real rename endpoint is `PATCH https://claude.ai/v1/sessions/{id}` (NOT under
  `/api/organizations/…` — those 404). But it is **service-worker-mediated**: a direct page
  `fetch`/XHR to it returns 405/404 because the SW injects the auth the gateway needs. Page-
  context fetch/XHR interceptors don't see the real call either. So you cannot script renames.
- The Chrome extension also blocks any JS response containing session ids/titles
  (`[BLOCKED: Sensitive key]` / `[BLOCKED: Base64 encoded data]`) — so you can't even bulk-read
  the list+titles out. Titles must be read **visually** (sidebar/header) or via `get_page_text`.
- **Dates ARE obtainable** (and the convention needs them): they live in IndexedDB
  `keyval-store → keyval → react-query-cache`, one object per session with `id`, `title`,
  `created_at`, `updated_at`. Date strings pass the filter when returned in isolation (no ids/
  titles in the same response). Per open session: read `created_at` for the id in
  `location.pathname`. (Bulk JS to get the date histogram works; bulk id→date does not, ids trip
  the base64 filter.)

**Rename mechanism (the ONLY reliable one):**
- Use the **header `⋮`** (top-right, ~1289,24), NOT the sidebar `⋮`. The sidebar reorders the
  instant a session becomes active, so a sidebar menu can target the wrong row. The header menu
  always targets the **currently-open** session.
- **The menu's item positions VARY per session** (different session types show/hide
  "Background tasks" / "Edit environment"), so Rename sits at a different y each time. ALWAYS
  screenshot the open menu and click the actual "Rename" row — never a memorised coordinate.
  (Clicking a stale coordinate misses, focus falls to the chat composer, and your typed title
  gets entered as a message — clear the composer if this happens.)
- Rename opens an **inline editable field in the header** with the title pre-selected →
  `cmd+a`, type the new name, **Enter**. Verify via a header zoom. Live, no relaunch.

Per-session cost is ~9 verified calls (open → get_page_text → date → ⋮ → screenshot → Rename →
cmd+a → type → Enter). There is no faster route — a large backlog is a genuine grind; tell the
user the scale before starting and consider scoping to recent/substantive sessions.

**A. Login gate — check FIRST, every run.**
   1. `list_connected_browsers` → `select_browser`. If no browser is connected, tell the user to
      open Chrome with the Claude extension and stop.
   2. `navigate` to `https://claude.ai/code`.
   3. Detect auth: logged-in shows the Recents sidebar + the account chip (e.g. "Justin · Max")
      bottom-left and a "New session" item. Logged-out shows a claude.ai sign-in screen.
   4. **If logged out: STOP and prompt the user to log in to claude.ai in that Chrome window,
      then re-run.** NEVER attempt to log in on their behalf — entering credentials is prohibited.

**B. Enumerate.** Read the Recents list (click "Show 30 more" until fully expanded). Each entry's
   visible text is its current title; `claude.ai`'s own auto-namer gives topic-only titles (e.g.
   "Lifecycle marketing operating models") — those are NOT the convention and need renaming.

**C. Name each.** Open the session, read its content, derive `YYYY-MM-DD - Topic - Status`.
   Already-convention titles get the same Status-freshness re-check as desktop. **Date sourcing:**
   the sidebar shows no date — read it from the session's first message / content; if genuinely
   undeterminable, ask the user rather than stamping a wrong date.

**D. Rename (proven mechanism).** Hover the sidebar entry → a `⋮` overflow button appears at its
   right edge → click it → **Rename** (or press `R`). The title becomes an **inline editable
   field with the text pre-selected** → `cmd+a`, type the new name, press **Enter** to commit
   (Escape cancels). Cloud renames are live — no relaunch needed.

---

Generate a session name in the standard format:

`YYYY-MM-DD - <Topic> - <Status>`

## On invocation

1. Use the session's own date (`YYYY-MM-DD` from its first transcript event), not necessarily today
2. Derive the **Topic** from the **Ask** — the user's opening request / what they came in wanting.
   It is the *subject of the first substantive user message*, not where the work drifted to.
3. Derive the **Status** from the **current Outcome** — where the work actually ended up by the
   last turn (answered, shipped, blocked, mid-build). Read the final assistant turn for this.
4. Output the suggested name on its own line as inline code
5. **Apply it** via `rename-session.sh "<name>" <cliSessionId>` for closed sessions. For the
   *current* session, the app owns the title — offer the name for a manual UI rename instead,
   since a disk write won't stick while it's active.

## Topic naming — rules

**The Topic comes from the Ask.** Anchor it to the user's opening request — the subject of the
first substantive user message — not to whatever the session later wandered into. If the user
asked "rename the Dunning templates in Braze", the Topic is the Dunning templates, even if the
session also refreshed their content along the way.

- 2–5 words, Title Case
- Name the *thing being worked on* (the subject of the Ask), not the action
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

**The Status comes from the current Outcome** — where the work actually landed by the final
turn, read from the last assistant message. Not the Ask restated, not a generic verb: the
*result*. A one-shot question that got answered is `Answered`; a build that shipped is `Done`
(add the substance: `Done 12 Of 12`); work that died on an error or a missing input is the
blocker (`Blocked On Stripo Export`, `No Visibility`); work still in flight is the live state
(`Diagnosing`, `Mid Build`). If the Ask was "what is X" and you replied with X, the Outcome is
`Answered` — never leave it as the question.

The Status is not a fixed vocabulary. It is a precise 2–6 word Title Case description of the
outcome, generated from the actual conversation context.

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

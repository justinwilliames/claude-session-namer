---
name: session-namer
description: >
  Generate or refresh a session name in the format YYYY-MM-DD - Topic - Status.
  Invoke when the user wants to name or rename the current Claude Code session,
  update the session name as work progresses, or needs a name to paste into the
  session title field. Triggers on: "name this session", "update the session name",
  "what should I call this chat", "session name", "/session-namer".
  Also fires automatically at the start of every new session via the SessionStart hook.
---

# Session Namer

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

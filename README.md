# session-namer

A Claude Code skill that automatically keeps your session titles up to date as you work.

Every time Claude finishes a response, the session title in the sidebar is updated to reflect what's actually happening — the topic you're working on and a precise, LLM-generated status. No clicking, no copying, no manual rename.

```
2026-06-26 - Activation Canvas - Fixing Entry Rules
2026-06-26 - PostHog Event Bug - Root Cause Found
2026-06-26 - HubSpot Audit - Reviewing Property Schema
```

## How it works

Two hooks run automatically:

1. **SessionStart hook** — injects a directive into every new session telling Claude to output a suggested session name at the end of every response, in the format `YYYY-MM-DD - Topic - Status`
2. **Stop hook** — after each response, parses that line from the transcript and writes it directly to the Claude Code session JSON file on disk

The title and `titleSource` fields in `~/Library/Application Support/Claude/claude-code-sessions/**/*.json` are updated atomically. Setting `titleSource: "user"` mirrors what happens when you rename a session manually in the sidebar, which locks it against Claude Code's own auto-naming.

No screen control. No UI automation. No cursor grabbing. Pure filesystem write.

## Prerequisites

- **macOS** — session files live in `~/Library/Application Support/Claude/`
- **Claude Code desktop app** — the session JSON files are specific to the desktop app
- **Python 3** — pre-installed on macOS Ventura and later

No other Claude Code skills are required. This is fully standalone.

## Installation

### Automatic

```bash
git clone https://github.com/justinwilliames/claude-session-namer.git
cd claude-session-namer
bash install.sh
```

### Manual

1. Copy the skill files:
   ```bash
   cp -r . ~/.claude/skills/session-namer
   chmod +x ~/.claude/skills/session-namer/hooks/*.sh
   chmod +x ~/.claude/skills/session-namer/scripts/*.sh
   chmod +x ~/.claude/skills/session-namer/scripts/*.py
   ```

2. Add the hooks to `~/.claude/settings.json`:

   Under `hooks.SessionStart`, add:
   ```json
   {
     "matcher": "",
     "hooks": [{
       "type": "command",
       "command": "~/.claude/skills/session-namer/hooks/session-namer-start.sh",
       "timeout": 5
     }]
   }
   ```

   Under `hooks.Stop`, add:
   ```json
   {
     "matcher": "",
     "hooks": [{
       "type": "command",
       "command": "~/.claude/skills/session-namer/hooks/session-namer-stop.sh",
       "timeout": 5
     }]
   }
   ```

   If `hooks` or its sub-keys don't exist yet, create them. See the [Claude Code hooks docs](https://docs.anthropic.com/en/docs/claude-code/hooks) for the full settings schema.

3. Restart Claude Code.

## Usage

**Automatic** — start a new session and the title updates after every response.

**Manual refresh** — invoke `/session-namer` at any point to get an updated name based on current progress. Useful when you've pivoted mid-session.

## Naming convention

```
YYYY-MM-DD - Topic - Status
```

| Part | Rules |
|---|---|
| **Date** | Today's date, set at session start |
| **Topic** | 2–5 words, Title Case — the thing being worked on, not the action |
| **Status** | 2–6 words, Title Case, LLM-generated — precisely what is happening right now |

Status is freeform, not a fixed list. Examples: `Fixing Entry Rules`, `Root Cause Found`, `Canvas QA Complete`, `Blocked On Stripo Export`, `Done`.

## File structure

```
session-namer/
├── SKILL.md                        # Claude Code skill definition
├── README.md
├── LICENSE
├── install.sh
├── hooks/
│   ├── session-namer-start.sh      # SessionStart hook — injects naming directive
│   └── session-namer-stop.sh       # Stop hook — parses name, calls rename script
└── scripts/
    ├── rename-session.sh           # Finds + rewrites the session JSON file
    ├── patch-session-json.py       # Atomic JSON patch (title + titleSource)
    ├── parse-session-name.py       # Extracts session name from transcript
    └── extract-field.py            # JSON stdin field extractor
```

## How the rename works (technical)

Claude Code stores one JSON file per session at:
```
~/Library/Application Support/Claude/claude-code-sessions/
  <account-uuid>/<workspace-uuid>/local_<session-uuid>.json
```

Each file has a `cliSessionId` field that matches the session UUID in the transcript filename (`~/.claude/projects/<project>/<uuid>.jsonl`). The Stop hook extracts the UUID from the transcript path, greps the session files for a matching `cliSessionId`, then atomically patches `title` and `titleSource`.

`titleSource: "user"` is the value Claude Code sets when you rename a session manually via the sidebar. Using it here prevents Claude Code from overwriting the title with its own auto-generated name.

## Limitations

- **macOS only** — session file paths are macOS-specific
- **Desktop app only** — the session JSON files don't exist in the CLI-only version
- **One session at a time** — the Stop hook targets the session whose transcript was just written; it does not touch other open sessions

## License

MIT

#!/usr/bin/env bash
# install.sh — Install the session-namer skill into ~/.claude/skills/
# and register its hooks in ~/.claude/settings.json

set -e

SKILL_DIR="$HOME/.claude/skills/session-namer"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing session-namer to $SKILL_DIR..."

# Copy skill files
mkdir -p "$SKILL_DIR/hooks" "$SKILL_DIR/scripts"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/"
cp "$SCRIPT_DIR/hooks/"*.sh "$SKILL_DIR/hooks/"
cp "$SCRIPT_DIR/scripts/"*.sh "$SKILL_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/"*.py "$SKILL_DIR/scripts/"

# Make scripts executable
chmod +x "$SKILL_DIR/hooks/"*.sh
chmod +x "$SKILL_DIR/scripts/"*.sh
chmod +x "$SKILL_DIR/scripts/"*.py

echo "Files installed."

# Register hooks in settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{"hooks":{}}' > "$SETTINGS"
fi

python3 << PYEOF
import json, sys, os

settings_path = os.path.expanduser("~/.claude/settings.json")
skill_dir = os.path.expanduser("~/.claude/skills/session-namer")

with open(settings_path) as f:
    settings = json.load(f)

if "hooks" not in settings:
    settings["hooks"] = {}

# SessionStart hook
start_hook = {
    "matcher": "",
    "hooks": [{
        "type": "command",
        "command": f"{skill_dir}/hooks/session-namer-start.sh",
        "timeout": 5
    }]
}

# Stop hook
stop_hook = {
    "matcher": "",
    "hooks": [{
        "type": "command",
        "command": f"{skill_dir}/hooks/session-namer-stop.sh",
        "timeout": 5
    }]
}

def hook_already_registered(hook_list, command):
    for entry in hook_list:
        for h in entry.get("hooks", []):
            if h.get("command") == command:
                return True
    return False

start_cmd = f"{skill_dir}/hooks/session-namer-start.sh"
stop_cmd = f"{skill_dir}/hooks/session-namer-stop.sh"

if "SessionStart" not in settings["hooks"]:
    settings["hooks"]["SessionStart"] = []
if not hook_already_registered(settings["hooks"]["SessionStart"], start_cmd):
    settings["hooks"]["SessionStart"].append(start_hook)
    print("Registered SessionStart hook.")
else:
    print("SessionStart hook already registered.")

if "Stop" not in settings["hooks"]:
    settings["hooks"]["Stop"] = []
if not hook_already_registered(settings["hooks"]["Stop"], stop_cmd):
    settings["hooks"]["Stop"].append(stop_hook)
    print("Registered Stop hook.")
else:
    print("Stop hook already registered.")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("settings.json updated.")
PYEOF

echo ""
echo "Done. Restart Claude Code to activate session-namer."
echo "Sessions will be renamed automatically after each response."

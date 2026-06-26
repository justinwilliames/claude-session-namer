#!/usr/bin/env python3
"""Generate a session name from transcript content using word frequency heuristics.
No external API calls — works entirely from the JSONL."""
import sys, json, re
from collections import Counter
from datetime import date

STOP_WORDS = {
    'this', 'that', 'with', 'from', 'have', 'been', 'will', 'would', 'could',
    'should', 'your', 'their', 'there', 'then', 'when', 'just', 'also', 'into',
    'about', 'which', 'what', 'where', 'some', 'more', 'very', 'need', 'want',
    'make', 'code', 'work', 'check', 'look', 'like', 'here', 'well', 'know',
    'sure', 'okay', 'right', 'good', 'done', 'going', 'doing', 'using', 'used',
    'take', 'keep', 'lets', 'help', 'think', 'than', 'them', 'they', 'these',
    'those', 'have', 'been', 'were', 'will', 'would', 'could', 'should', 'shall',
    'might', 'must', 'each', 'such', 'much', 'many', 'most', 'only', 'same',
    'other', 'after', 'before', 'every', 'first', 'still', 'never', 'always',
    'claude', 'please', 'thanks', 'thank', 'hello', 'email', 'braze', 'stripo',
}

BOILERPLATE_PREFIXES = [
    "This session is being continued",
    "Summary:",
    "Continue the conversation",
    "If you need specific details",
]


def is_boilerplate(text):
    return any(text.startswith(p) for p in BOILERPLATE_PREFIXES)


def extract_user_text(ev):
    content = ev.get("message", {}).get("content", "")
    if isinstance(content, str):
        return content.strip()
    elif isinstance(content, list):
        parts = []
        for chunk in content:
            if not isinstance(chunk, dict):
                continue
            if chunk.get("type") == "text":
                parts.append(chunk.get("text", "").strip())
        return " ".join(parts).strip()
    return ""


def main():
    path = sys.argv[1]
    date_str = sys.argv[2] if len(sys.argv) > 2 else str(date.today())

    user_messages = []

    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue

            if ev.get("type") != "user":
                continue
            if ev.get("isCompactSummary"):
                continue

            text = extract_user_text(ev)
            if not text or len(text) < 10:
                continue
            if is_boilerplate(text):
                continue

            # Skip pure tool-result messages
            content = ev.get("message", {}).get("content", "")
            if isinstance(content, list) and content and all(
                isinstance(c, dict) and c.get("type") == "tool_result"
                for c in content
            ):
                continue

            user_messages.append(text)

    if not user_messages:
        sys.exit(1)

    # Topic: word frequency across ALL user messages
    all_text = " ".join(user_messages)
    words = re.findall(r'\b[a-zA-Z]{5,}\b', all_text.lower())
    freq = Counter(w for w in words if w not in STOP_WORDS)
    top_words = [w.title() for w, _ in freq.most_common(4)]
    topic = " ".join(top_words[:2]) if top_words else "Session"

    # Status: first meaningful words from the LAST real user message
    last_msg = user_messages[-1]
    last_words = re.findall(r'\b[a-zA-Z]{5,}\b', last_msg.lower())
    status_words = [w.title() for w in last_words if w not in STOP_WORDS][:2]
    status = " ".join(status_words) if status_words else "Working"

    print(f"{date_str} - {topic} - {status}")


main()

#!/usr/bin/env python3
"""Generate a session name from transcript content — no network, no LLM, no API key.

Format: ``YYYY-MM-DD - Topic - Status``

Design (v2): anchor the Topic on the *opening* user message (which almost always
states the task) rather than counting word frequency across the whole transcript.
Derive the Status from the *final* user message, with explicit handling for terminal
states (interrupts, handoffs, acknowledgements). The date is the session's own start
date, taken from the first transcript event — never "today" — so naming an old
session backfills the correct date.
"""
import sys, json, re
from collections import OrderedDict
from datetime import date

# Words that never make a good Topic/Status token.
STOP_WORDS = {
    'this', 'that', 'with', 'from', 'have', 'been', 'will', 'would', 'could',
    'should', 'your', 'their', 'there', 'then', 'when', 'just', 'also', 'into',
    'about', 'which', 'what', 'where', 'some', 'more', 'very', 'need', 'want',
    'make', 'look', 'like', 'here', 'well', 'know', 'sure', 'okay', 'right',
    'going', 'doing', 'take', 'keep', 'lets', 'help', 'think', 'than', 'them',
    'they', 'these', 'those', 'were', 'shall', 'might', 'must', 'each', 'such',
    'much', 'many', 'most', 'only', 'same', 'other', 'after', 'before', 'every',
    'still', 'never', 'always', 'please', 'thanks', 'thank', 'hello', 'give',
    'using', 'used', 'over', 'down', 'back', 'good', 'done', 'work', 'check',
    'could', 'would', 'really', 'maybe', 'something', 'anything', 'everything',
    'because', 'while', 'where', 'first', 'last', 'next', 'now', 'today',
    'can', 'you', 'the', 'and', 'for', 'are', 'but', 'not', 'all', 'any',
    # leading imperative / filler verbs that are never the Topic itself
    'taking', 'resume', 'pick', 'bunch', 'following', 'introducing', 'spawn',
    'left', 'run', 'running', 'continue', 'continuing', 'start', 'starting',
    'wanna', 'gonna', 'able', 'help', 'helping', 'give', 'giving', 'get',
}

# Domain proper nouns — if any appear in the opening message, they anchor the Topic.
DOMAIN_TERMS = OrderedDict((t.lower(), t) for t in [
    'Braze', 'Stripo', 'PostHog', 'Hightouch', 'HubSpot', 'Stripe', 'Slack',
    'LinkedIn', 'Notion', 'Sophiie', 'Orbit', 'Caldwell', 'Codex', 'AppsFlyer',
    'Figma', 'Canvas', 'Dashboard', 'Activation', 'Dunning', 'Churn', 'Retention',
    'Onboarding', 'Liquid', 'Segment', 'Webhook', 'Changelog', 'Skill', 'Hook',
    'PRD', 'OKR', 'Email', 'SMS', 'Push', 'Template', 'Favicon', 'Logo',
    'Dictation', 'Telemetry', 'Routine', 'Digest', 'Upsell', 'Lifecycle',
])

BOILERPLATE_PREFIXES = (
    "This session is being continued", "Summary:", "Continue the conversation",
    "If you need specific details", "Base directory", "Caveat:", "<system-reminder",
)


def clean(text):
    """Strip slash-commands, file paths, URLs, code spans, task tags."""
    text = re.sub(r'```.*?```', ' ', text, flags=re.S)        # fenced code
    text = re.sub(r'`[^`]*`', ' ', text)                       # inline code
    text = re.sub(r'<[^>]+>', ' ', text)                       # xml-ish tags
    text = re.sub(r'https?://\S+', ' ', text)                  # urls
    text = re.sub(r'@?"?/[^\s"]+', ' ', text)                  # abs paths
    text = re.sub(r'(?:^|\s)/[a-z][\w-]*', ' ', text)          # /slash-commands
    return re.sub(r'\s+', ' ', text).strip()


def extract_user_text(ev):
    content = ev.get("message", {}).get("content", "")
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        # Pure tool-result turns carry no human intent.
        if content and all(isinstance(c, dict) and c.get("type") == "tool_result" for c in content):
            return ""
        return " ".join(
            c.get("text", "").strip() for c in content
            if isinstance(c, dict) and c.get("type") == "text"
        ).strip()
    return ""


def title_phrase(text, n=3):
    """Build a Title-Case phrase from the salient words in reading order.

    Walks the words left-to-right, keeping domain proper-nouns and meaningful
    non-stopwords, de-duplicated by stem (so 'Caldwell' and 'Caldwell-Speak'
    don't both land). Reading order is preserved — no domain-first reshuffle —
    which keeps the phrase grammatical."""
    picked, seen = [], set()
    for raw in re.findall(r"\b[a-zA-Z][a-zA-Z-]{2,}\b", text):
        if len(picked) >= n:
            break
        head = raw.split("-")[0]              # 'Caldwell-Speak' -> 'Caldwell'
        wl = head.lower()
        if len(head) < 4 and wl not in DOMAIN_TERMS:
            continue
        if wl in STOP_WORDS or wl in seen:
            continue
        seen.add(wl)
        picked.append(DOMAIN_TERMS.get(wl, head.title()))
    return " ".join(picked) if picked else ""


def status_from_last(text):
    low = text.lower()
    if 'request interrupted' in low:
        return "Interrupted"
    if 'task-notification' in low or 'handoff' in low or 'hand off' in low:
        return "Handoff"
    if re.fullmatch(r'(thanks?|perfect|great|lgtm|ship it|nice|cheers|ok|done)[.! ]*', low.strip()):
        return "Done"
    phrase = title_phrase(clean(text), n=3)
    return phrase or "In Progress"


def session_date(path, fallback):
    try:
        for line in open(path):
            line = line.strip()
            if not line:
                continue
            ev = json.loads(line)
            ts = ev.get("timestamp")
            if ts:
                return ts[:10]
    except Exception:
        pass
    return fallback


def main():
    path = sys.argv[1]
    fallback_date = sys.argv[2] if len(sys.argv) > 2 else str(date.today())

    msgs = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            if ev.get("type") != "user" or ev.get("isCompactSummary") or ev.get("isMeta"):
                continue
            text = extract_user_text(ev)
            if not text or len(text) < 10 or text.startswith(BOILERPLATE_PREFIXES):
                continue
            msgs.append(text)

    if not msgs:
        sys.exit(1)

    topic = title_phrase(clean(msgs[0]), n=3) or "Session"
    status = status_from_last(msgs[-1]) if len(msgs) > 1 else "Started"
    print(f"{session_date(path, fallback_date)} - {topic} - {status}")


main()

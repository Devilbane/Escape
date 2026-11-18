#!/usr/bin/env python3
"""Writes a one-line development status for the Twitch chat (Nightbot `$(urlfetch ...)`).

Usage: dev_status.py OUTPUT_FILE   (needs the `gh` CLI and GH_TOKEN, as in GitHub Actions)
Reads the open and recently merged pull requests and keeps the line under 400 characters,
the limit Nightbot allows for a chat message.
"""
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

REPO = "devilbane/escape"
LIMIT = 390
RECENT_DAYS = 7


def gh(*args):
    out = subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def clean(title):
    title = re.sub(r"^\s*\[?(WIP|Draft)\]?:?\s*", "", title, flags=re.I)
    title = re.sub(r"^(feat|fix|chore|docs)(\([^)]*\))?:\s*", "", title, flags=re.I)
    title = re.sub(r"\s*\(#\d+\)\s*$", "", title).strip()
    return title[:1].upper() + title[1:] if title else title


def pick(titles, budget):
    """Takes titles while they fit in budget; returns (shown, hidden count)."""
    shown, used = [], 0
    for t in titles:
        add = len(t) + 2
        if used + add > budget and shown:
            break
        shown.append(t if used + add <= budget else t[: max(budget - used - 3, 10)] + "...")
        used += add
    return shown, len(titles) - len(shown)


def build():
    open_prs = [{"title": p["title"], "createdAt": p["created_at"]}
                for p in gh("api", f"repos/{REPO}/pulls?state=open&per_page=50")]
    closed = gh("api", f"repos/{REPO}/pulls?state=closed&sort=updated&direction=desc&per_page=50")
    merged = [{"title": p["title"], "mergedAt": p["merged_at"]} for p in closed if p.get("merged_at")]
    since = datetime.now(timezone.utc) - timedelta(days=RECENT_DAYS)
    merged = [p for p in merged
              if datetime.fromisoformat(p["mergedAt"].replace("Z", "+00:00")) >= since]
    # Newest first.
    open_prs.sort(key=lambda p: p["createdAt"], reverse=True)
    merged.sort(key=lambda p: p["mergedAt"], reverse=True)
    working = [clean(p["title"]) for p in open_prs]
    shipped = [clean(p["title"]) for p in merged]

    head = "Escape! dev status"
    parts = []
    if working:
        shown, hidden = pick(working, 170)
        parts.append("Working on: " + "; ".join(shown) + (f" (+{hidden} more)" if hidden else ""))
    if shipped:
        shown, hidden = pick(shipped, 150)
        parts.append(f"Shipped this week: " + "; ".join(shown) + (f" (+{hidden} more)" if hidden else ""))
    if not parts:
        parts.append("Quiet right now, check back soon!")
    line = f"{head} | " + " | ".join(parts)
    return line[:LIMIT]


if __name__ == "__main__":
    text = build()
    with open(sys.argv[1], "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print(text)

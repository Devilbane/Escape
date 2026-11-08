"""Prints the patch notes the client ships: the header comments plus the newest two sections
("## ..." blocks) of docs/patch_notes.txt, so older history stays in the repo but not in the launcher.
Same rule as LauncherScript.recent_notes. Usage: python3 tools/recent_notes.py docs/patch_notes.txt"""
import sys

KEEP = 2


def recent(text, keep=KEEP):
    out, seen = [], 0
    for line in text.splitlines():
        if line.startswith("##"):
            seen += 1
            if seen > keep:
                break
        out.append(line)
    return "\n".join(out).rstrip() + "\n"


if __name__ == "__main__":
    sys.stdout.write(recent(open(sys.argv[1], encoding="utf-8").read()))

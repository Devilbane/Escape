"""Builds the patch notes the client ships from docs/patch_notes.txt (header + history) and the
per-change fragments in docs/patch_notes.d/*.txt (each PR adds its own file, so PRs never conflict).

  python3 tools/patch_notes.py combined   all notes: header, "## Latest changes" (fragments), history
  python3 tools/patch_notes.py recent     the same, cut to the newest two sections (what ships)
  python3 tools/patch_notes.py fold "Heading"   move the fragments into docs/patch_notes.txt as a new
                                          top section and delete them

Same section rule as LauncherScript.recent_notes."""
import glob
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
NOTES = os.path.join(ROOT, "docs", "patch_notes.txt")
FRAGMENTS = os.path.join(ROOT, "docs", "patch_notes.d")
KEEP = 2
TITLE = "Latest changes"


def fragment_lines(folder=FRAGMENTS):
    lines = []
    for path in sorted(glob.glob(os.path.join(folder, "*.txt"))):
        for line in open(path, encoding="utf-8").read().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                lines.append(line if line.startswith("-") else "- " + line)
    return lines


def split_header(text):
    """(header, rest): the leading comment/blank lines, then everything from the first section."""
    lines = text.splitlines()
    i = 0
    while i < len(lines) and not lines[i].startswith("##"):
        i += 1
    return "\n".join(lines[:i]).rstrip(), "\n".join(lines[i:]).strip()


def combined(text, fragments, title=TITLE):
    header, rest = split_header(text)
    parts = [header]
    if fragments:
        parts.append("## " + title + "\n" + "\n".join(fragments))
    if rest:
        parts.append(rest)
    return "\n\n".join(p for p in parts if p) + "\n"


def recent(text, keep=KEEP):
    out, seen = [], 0
    for line in text.splitlines():
        if line.startswith("##"):
            seen += 1
            if seen > keep:
                break
        out.append(line)
    return "\n".join(out).rstrip() + "\n"


def read_notes():
    return open(NOTES, encoding="utf-8").read()


def fold(heading):
    frags = fragment_lines()
    if not frags:
        sys.exit("nothing to fold")
    text = combined(read_notes(), frags, heading)
    open(NOTES, "w", encoding="utf-8").write(text)
    for path in glob.glob(os.path.join(FRAGMENTS, "*.txt")):
        os.remove(path)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "recent"
    if cmd == "fold":
        fold(sys.argv[2] if len(sys.argv) > 2 else TITLE)
    elif cmd == "combined":
        sys.stdout.write(combined(read_notes(), fragment_lines()))
    elif cmd == "recent":
        sys.stdout.write(recent(combined(read_notes(), fragment_lines())))
    else:
        sys.exit(__doc__)

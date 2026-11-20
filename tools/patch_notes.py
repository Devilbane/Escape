"""Builds the patch notes the client ships from docs/patch_notes.txt (header + history) and the
per-change fragments in docs/patch_notes.d/*.txt (each PR adds its own file, so PRs never conflict).

  python3 tools/patch_notes.py combined   all notes: header, "## Latest changes" (fragments), history
  python3 tools/patch_notes.py recent     the same, cut to the newest two sections (old behaviour)
  python3 tools/patch_notes.py build [REF]  what a build ships: only the fragments added since REF (the last
                                          published build's commit), under "## New in this build"; no REF
                                          or an unknown one ships every fragment
  python3 tools/patch_notes.py fold "Heading"   move the fragments into docs/patch_notes.txt as a new
                                          top section and delete them
  python3 tools/patch_notes.py history BUILD VERSION [REF] [PREVIOUS.json]
                                          the archive of every build's notes (docs/patch_history.json, shown
                                          in the compendium): the committed archive, the one published with
                                          the previous build (PREVIOUS.json, may be missing) and this build's
                                          notes (the fragments new since REF), newest build first; an
                                          empty BUILD only merges the archives

Same section rule as LauncherScript.recent_notes."""
import datetime
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
NOTES = os.path.join(ROOT, "docs", "patch_notes.txt")
HISTORY = os.path.join(ROOT, "docs", "patch_history.json")
FRAGMENTS = os.path.join(ROOT, "docs", "patch_notes.d")
KEEP = 2
TITLE = "Latest changes"


def fragment_lines_of(path):
    lines = []
    for line in open(path, encoding="utf-8").read().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            lines.append(line if line.startswith("-") else "- " + line)
    return lines


def fragment_lines(folder=FRAGMENTS):
    lines = []
    for path in sorted(glob.glob(os.path.join(folder, "*.txt"))):
        lines.extend(fragment_lines_of(path))
    return lines


def added_since(ref):
    """Names of the fragment files added after commit/tag `ref`, or None when it can't be told."""
    if not ref:
        return None
    try:
        out = subprocess.check_output(
            ["git", "diff", "--name-only", "--diff-filter=A", ref + "..HEAD", "--", "docs/patch_notes.d/"],
            cwd=ROOT, text=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, OSError):
        return None
    return {os.path.basename(n) for n in out.split() if n.endswith(".txt")}


def build_notes(text, ref, title="New in this build"):
    """The notes one build ships: header plus only the fragments new since the previous build."""
    names = added_since(ref)
    lines = []
    for path in sorted(glob.glob(os.path.join(FRAGMENTS, "*.txt"))):
        if names is not None and os.path.basename(path) not in names:
            continue
        lines.extend(fragment_lines_of(path))
    header, _ = split_header(text)
    return "\n\n".join(p for p in [header, "## " + title + "\n" + "\n".join(lines) if lines else ""] if p) + "\n"


def change_lines(text):
    """The changes of a notes text, without their "- ": headings and comments are dropped."""
    return [line.strip()[2:].strip() for line in text.splitlines() if line.strip().startswith("- ")]


def merge_history(*archives):
    """One archive from several: each build once (the first archive that has it wins), builds
    without a change left out, newest build first."""
    seen, builds = set(), []
    for archive in archives:
        for entry in (archive or {}).get("builds", []):
            key = str(entry.get("build", ""))
            if key == "" or key in seen or not entry.get("notes"):
                continue
            seen.add(key)
            builds.append(entry)
    builds.sort(key=lambda e: int(e["build"]) if str(e["build"]).isdigit() else -1, reverse=True)
    return {"builds": builds}


def read_history(path=HISTORY):
    try:
        return json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError):
        return {"builds": []}


def history(build, version, ref, previous_path=""):
    """The archive a build ships: this build's notes on top of the published and committed ones."""
    if not build:
        return merge_history(read_history(previous_path) if previous_path else None, read_history())
    entry = {"version": version + "." + str(build), "build": str(build),
             "date": datetime.date.today().isoformat(),
             "notes": change_lines(build_notes(read_notes(), ref))}
    previous = read_history(previous_path) if previous_path else None
    return merge_history({"builds": [entry]}, previous, read_history())


def history_json(archive):
    return json.dumps(archive, indent=1, ensure_ascii=False) + "\n"


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
    elif cmd == "build":
        sys.stdout.write(build_notes(read_notes(), sys.argv[2] if len(sys.argv) > 2 else ""))
    elif cmd == "history":
        args = sys.argv[2:] + [""] * 4
        sys.stdout.write(history_json(history(args[0], args[1], args[2], args[3])))
    elif cmd == "combined":
        sys.stdout.write(combined(read_notes(), fragment_lines()))
    elif cmd == "recent":
        sys.stdout.write(recent(combined(read_notes(), fragment_lines())))
    else:
        sys.exit(__doc__)

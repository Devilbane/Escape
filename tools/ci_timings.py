#!/usr/bin/env python3
"""Refreshes tests/ci_timings.txt from the logs of recent "Tests" runs.

Download a run's logs (Actions > a run > ... > Download log archive), unpack them, and pass the shard
logs; several runs at once give a steadier average:

    python3 tools/ci_timings.py run1/*.txt run2/*.txt

Every "ok <test> (Ns)" or "FLAKY <test> ... (Ns)" line counts. A test that none of the logs mention keeps
its old value; a test that no longer exists in tests/ is dropped.
"""
import collections
import os
import re
import sys

PATH = "tests/ci_timings.txt"
LINE = re.compile(r"\b(?:ok|FLAKY) +(\S+\.gd)\b.*\((\d+)s\)")

old, header = {}, []
for line in open(PATH, encoding="utf-8"):
    if line.startswith("#"):
        header.append(line.rstrip("\n"))
    elif line.strip():
        name, secs = line.split()
        old[name] = int(secs)

seen = collections.defaultdict(list)
for path in sys.argv[1:]:
    for line in open(path, encoding="utf-8", errors="replace"):
        m = LINE.search(line)
        if m:
            seen[m.group(1)].append(int(m.group(2)))
if not seen:
    sys.exit("No 'ok <test> (Ns)' lines found in the given logs.")

new = {n: s for n, s in old.items()}
new.update({n: max(1, round(sum(v) / len(v))) for n, v in seen.items()})
names = sorted(n for n in new if os.path.exists(os.path.join("tests", n)))
with open(PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(header + ["%s %d" % (n, new[n]) for n in names]) + "\n")
print("%d tests measured, %d lines written to %s" % (len(seen), len(names), PATH))

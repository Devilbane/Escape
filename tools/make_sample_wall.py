#!/usr/bin/env python3
"""Writes walls/sample_three_paths.txt (the sample climbing wall, see scripts/wall_map.gd for the format).
Run: python3 tools/make_sample_wall.py"""
W = H = 24
hold = {}   # (c, r) -> malus
dirs = {}   # (c, r) -> set of letters
haz = {}
gaps = []
markers = [(5, 14, "body"), (9, 4, "cave"), (11, 0, "garden"), (5, 13, "camp"), (9, 6, "camp"), (11, 16, "camp")]
OPP = {"u": "d", "d": "u", "l": "r", "r": "l"}
STEP = {"u": (0, -1), "d": (0, 1), "l": (-1, 0), "r": (1, 0)}

def put(c, r, m):
    hold[(c, r)] = m
    dirs.setdefault((c, r), set())

def walk(start, moves, malus):
    """moves like 'u6 r3 u4': climb from start; every square is a hold, linked both ways to the next."""
    c, r = start
    i = 0
    put(c, r, malus(0))
    for mv in moves.split():
        d, n = mv[0], int(mv[1:])
        for _ in range(n):
            dc, dr = STEP[d]
            nc, nr = c + dc, r + dr
            i += 1
            put(nc, nr, malus(i))
            dirs[(c, r)].add(d)
            dirs[(nc, nr)].add(OPP[d])
            c, r = nc, nr
    return c, r

def run(start, count, direction, malus):
    """A straight run of holds from `start` (already a hold), linked both ways."""
    c, r = start
    for _ in range(count):
        dc, dr = STEP[direction]
        nc, nr = c + dc, r + dr
        put(nc, nr, malus)
        dirs[(c, r)].add(direction)
        dirs[(nc, nr)].add(OPP[direction])
        c, r = nc, nr
    return c, r

def jump_gap(rect, row, left, right):
    """A crack with a hold on each side that points at it (`left` and `right` are the squares beside it)."""
    gaps.append(rect)
    dirs[left].add("r")
    dirs[right].add("l")

# Left: the scree path, long and gentle (malus 0..2), loose stones in the middle.
walk((2, 23), "u6 r3 u6 l2 u3 r6 u8", lambda i: 0 if i % 7 else 1)
for cell in ((5, 12), (5, 11), (4, 11), (3, 10)):
    haz[cell] = "s"
# Centre: the chimney, a medium climb (malus 2..4) with a sheet of ice and a wet patch.
walk((11, 23), "u9 l1 u6 r1 u8", lambda i: 2 + (i % 3))
for r in range(18, 21):
    haz[(11, r)] = "i"
haz[(10, 13)] = "i"
haz[(10, 14)] = "i"
haz[(11, 8)] = "w"
# Right: the overhang, short and steep (malus 5..7), wet moss low down.
walk((20, 23), "u10 l2 u13", lambda i: 5 + (i % 3))
haz[(20, 21)] = "w"
haz[(20, 20)] = "w"
# Connector 1 (row 17): from the scree path across a 2 m crack to the chimney.
run((5, 17), 2, "r", 3)
run((11, 17), 1, "l", 3)
jump_gap((8, 17, 2, 1), 17, (7, 17), (10, 17))
# Connector 2 (row 11): from the chimney across a 3 m crack (6 square metres) to the overhang.
run((10, 11), 3, "r", 4)
run((18, 11), 1, "l", 4)
jump_gap((14, 11, 3, 2), 11, (13, 11), (17, 11))
# The shortcut near the top (row 3): a 4 m crack (8 square metres) between chimney and overhang.
run((11, 3), 2, "r", 5)
jump_gap((14, 3, 4, 2), 3, (13, 3), (18, 3))

def lines():
    out = ["# Kletterwand: ein Feld ist ein Meter. [holds]: Malus 0-9 und Richtungen udlr, - ist glatter Fels.",
           "name: Die drei Pfade", "level: 2", "summit: 11_die_freiheit.txt:square", "size: %d %d" % (W, H), "[holds]"]
    for r in range(H):
        row = []
        for c in range(W):
            if (c, r) in hold:
                row.append(str(hold[(c, r)]) + "".join(l for l in "udlr" if l in dirs[(c, r)]))
            else:
                row.append("-")
        out.append(" ".join(row))
    out.append("[hazards]")
    for r in range(H):
        out.append("".join(haz.get((c, r), ".") for c in range(W)))
    out.append("[gaps]")
    for g in gaps:
        out.append("%d %d %d %d" % g)
    out.append("[markers]")
    for c, r, kind in markers:
        assert (c, r) in hold, (c, r)
        out.append("%d %d %s" % (c, r, kind))
    return "\n".join(out) + "\n"

if __name__ == "__main__":
    open("walls/sample_three_paths.txt", "w").write(lines())

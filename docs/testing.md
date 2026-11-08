# Testing and CI

Tests are headless Godot scripts in `tests/`: `godot --headless -s tests/<name>.gd` (add
`--fixed-fps 60` for tests that move bodies). A test prints `PASS` when it is happy.

## Fast checks: every pull request and every push to main

`.github/workflows/web.yml` names the tests one by one and then runs every other `tests/*.gd` in a
loop (not `profile_*.gd` and not the play-through). A new test therefore runs from the day it is
added; it does not need an entry in the workflow. The loop only warns for now, because many of those
tests were never run in CI; fix or list them one by one in `web.yml` to make them blocking.
The browser export and the Windows build follow on main and do not wait for anything slower.

## Full play-through: only when it matters

`tests/play_all_levels.gd` plays every level and takes about 28 minutes, so it lives in its own
workflow, `.github/workflows/playthrough.yml`. It runs
- on a pull request that touches character or progression code (the hero, level and XP, items and
  loot, quests, reputation, saves, the game loop, enemies, maps in `levels/`; the path list is in the
  workflow),
- on a pull request labelled `playthrough` (use it when a change is risky but not on that list),
- every night on main, and
- by hand: Actions > Full play-through > Run workflow.

On any other pull request the job starts, finds nothing to do and ends within seconds.

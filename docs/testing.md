# Testing and CI

Tests are headless Godot scripts in `tests/`: `godot --headless -s tests/<name>.gd` (add
`--fixed-fps 60` for tests that move bodies). A test prints `PASS` when it is happy.

## Fast checks: every pull request and every push to main

`.github/workflows/web.yml` runs the tests in parallel shards, so a pull request gets its answer in minutes
instead of half an hour. The tests that block are listed in `tests/ci_manifest.txt` (file, timeout, whether
it needs `--fixed-fps 60`, how it counts as passed); `tests/ci_shard.sh` runs every n-th one, 8 shards in a
matrix. The same script runs locally: `tests/ci_shard.sh blocking 0 1` runs them all.

Every other `tests/*.gd` (not `profile_*.gd` and not the play-through) runs in 4 non-blocking `extra` shards.
A new test therefore runs from the day it is added without an entry anywhere; it only warns until it has
been run in CI for a while. Fix it and add a line to `tests/ci_manifest.txt` to make it block.

The workflow is called "Tests". Its last job, `tests`, gathers the shards: it passes only when every blocking
shard passed. That is the single check to require on pull requests, and the Windows build on main waits only
for it (never for the play-through, the extra shards or the browser export). Adding or removing shards never
changes that name.

`docs/patch_notes.txt` is marked `merge=union` in `.gitattributes`, so two branches that each add a line at the
top merge without a conflict when git does the merge (rebase, `git merge`). GitHub's web "resolve conflicts"
view ignores that setting; update the branch locally in that case.

## Releases: Windows first

The Windows client is the main release. Every push to main that passes the fast checks makes
`.github/workflows/desktop.yml` ("Windows download") build the launcher and the game and publish them on
the release "windows" (Escape-Windows.zip, `version.json`, ...), which is what the launcher and players use.

The browser version is optional. `.github/workflows/browser.yml` ("Browser version") only runs by hand
(Actions > Browser version > Run workflow) and, when run on main, deploys to GitHub Pages. It does not
run on pull requests or pushes and nothing waits for it.

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

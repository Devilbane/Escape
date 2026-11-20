# Testing and CI

Tests are headless Godot scripts in `tests/`: `godot --headless -s tests/<name>.gd` (add
`--fixed-fps 60` for tests that move bodies). A test prints `PASS` when it is happy.

## Fast checks: every pull request and every push to main

`.github/workflows/web.yml` runs the tests in parallel shards, so a pull request gets its answer in minutes
instead of half an hour. The tests that block are listed in `tests/ci_manifest.txt` (file, timeout, whether
it needs `--fixed-fps 60`, how it counts as passed); `tests/ci_shard.sh` splits them into 8 shards in a matrix
by their measured length (`tests/ci_timings.txt`): longest first, each to the shard with the least work so far, so
all shards end at about the same time. A test missing from that file counts as 15 s. Refresh it now and then
from a run's logs (Actions > a run > Download log archive, unpack, then
`python3 tools/ci_timings.py <folder>/*.txt`); an outdated file only makes the split less even, never wrong.
The same script runs locally: `tests/ci_shard.sh blocking 0 1` runs them all.

Every job also restores the imported project (`.godot`) from the cache that pushes to main store
(`.github/actions/godot-setup`), so the import only handles what changed.

A test that fails is run once more. If it passes the second time it is reported as **flaky** (a warning on the run
and a line in the job summary) and does not block; a test that fails twice blocks. Treat every flaky report as a
bug in the test: seed the randomness (`seed(n)` in `_initialize`), wait for events or physics frames instead of
wall time, and read values such as `max_hit()` before the blow that trains a skill.

A pull request that changes only documentation (`docs/`, `balance/`, `*.md`) skips the shards; `tests` still
reports green. The full suite, extra shards included, also runs every night on main.

Every other `tests/*.gd` (not `profile_*.gd` and not the play-through) runs in 4 non-blocking `extra` shards.
On a pull request they start only after `tests` has reported, so they never take a runner the blocking shards
need (GitHub runs only so many jobs at once); on main and at night they run alongside the blocking shards.
A new test therefore runs from the day it is added without an entry anywhere; it only warns until it has
been run in CI for a while. Fix it and add a line to `tests/ci_manifest.txt` to make it block.

Tests listed in `tests/ci_on_demand.txt` (now `slime_siege.gd`) are skipped by both the blocking and the extra
shards, because they are slow or flaky in CI. They run only on demand: Actions > "On-demand tests" > Run
workflow (`.github/workflows/on_demand_tests.yml`, optionally with one file name), or locally with
`tests/ci_shard.sh on_demand 0 1`.

The workflow is called "Tests". Its last job, `tests`, gathers the shards: it passes only when every blocking
shard passed. That is the single check to require on pull requests, and the Windows build on main waits only
for it (never for the play-through, the extra shards or the browser export). Adding or removing shards never
changes that name.

Patch notes do not conflict: every PR adds its own file in `docs/patch_notes.d/` and the release workflow
combines them with `docs/patch_notes.txt` (`tools/patch_notes.py`).

## Releases: Windows first

The Windows client is the main release. Every push to main that passes the fast checks makes
`.github/workflows/desktop.yml` ("Windows download") build the launcher and the game and publish them on
the release "windows" (Escape-Windows.zip, `version.json`, ...), which is what the launcher and players use.

The browser version is optional. `.github/workflows/browser.yml` ("Browser version") only runs by hand
(Actions > Browser version > Run workflow) and, when run on main, deploys to GitHub Pages. It does not
run on pull requests or pushes and nothing waits for it.

## Full play-through: nightly and on demand

`tests/play_all_levels.gd` plays every level and takes a long time, so it lives in its own
workflow, `.github/workflows/playthrough.yml`, and does not run on pull requests (it used to, and took a runner
away from the test shards). It runs
- every night on main, and
- by hand: Actions > Full play-through > Run workflow (pick a branch to try a risky change before merging).

## Merge safety: test every pull request on current main

Two pull requests that each pass alone can break main together. In the repository settings
(Settings > Branches > branch protection rule for `main`, or Settings > Rules > Rulesets) turn on:

1. **Require status checks to pass before merging**, with the single check `tests` (never `build`, `tests-shard (n)` or `extra-tests (n)`).
2. **Require branches to be up to date before merging** ("strict" status checks). A pull request that is behind main
   then has to be updated and re-tested before it can merge. Or, better when several pull requests land at once,
   **Require merge queue**: GitHub merges each pull request on top of the queue and tests that result.

`web.yml` already listens to `merge_group`, so `tests` runs for queued merges.

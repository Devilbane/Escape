# Testing and CI

Tests are headless Godot scripts in `tests/`: `godot --headless -s tests/<name>.gd` (add
`--fixed-fps 60` for tests that move bodies). A test prints `PASS` when it is happy.

## What goes in the required check

Every pull request waits for the required check, so it holds only what is worth that wait. When you add a test,
put it in one of three lists:

- **Required, `tests/ci_manifest.txt`:** fast, deterministic tests of core logic. Saving and loading, combat,
  items, trading and crafting, collisions and getting stuck, and the checks that keep the data whole (map letters,
  monster families, English texts, the event bus, the map workshop's `validate()`). Keep each under about 30 s,
  seed its randomness and wait for events, not wall time.
- **Quests, `tests/ci_quests.txt`:** the tests of a quest or dungeon once it is finished. Each line names the
  paths it covers (its scripts and maps); a pull request runs the test in the required check only when it touches
  one of them or the test file itself. While a quest is still being built, keep its test in the manifest and move
  it here when it is done.
- **Nightly, `tests/ci_nightly.txt`:** looks and screenshots, sounds, ambient life (villagers, animals, birds,
  weather, seasons), timing-based simulations and everything else that is not core logic. They run every night
  and never block a merge.

- **Scoped, `tests/ci_scopes.txt`:** a required test can also be given the paths it covers (`file | paths`). It stays
  in `ci_manifest.txt`, but a pull request skips it unless it touches one of those paths or the test file. It is
  skipped only when every changed file is known (matches some scoped test's paths, or is neutral: `scripts/lang/*`,
  `levels/*`, `assets/*`, `shaders/*`, docs). One change to shared code (`game.gd`, `player.gd`, items, saving,
  `project.godot`, scenes, workflows, `tests/ci_*`) runs the whole required list. Nightly and manual runs always run
  everything.

**Standing rule for every new test:** it must say when it is relevant. Core logic goes in the manifest (and gets a
scope if it lives in its own files, as the house, workshop and launcher features do); a finished quest or dungeon
goes in `ci_quests.txt` with its paths; anything else goes to nightly. Never add an unscoped test that only one
feature can break. `tests/ci_select.sh` prints `skip=` for what a branch would leave out.

A test listed nowhere also runs every night, with the defaults (120 s, `--fixed-fps 60`, PASS and no FAIL).
When in doubt, choose nightly: a missed nightly failure costs a day, a slow or flaky required test costs every
pull request. Move a required test that turns flaky to the nightly list until it is fixed.

## Fast checks: every pull request and every push to main

`.github/workflows/web.yml` runs the required tests in parallel shards, so a pull request gets its answer in
minutes. The `scope` job looks at the changed files (`tests/ci_select.sh`) and picks:

- the required tests in `tests/ci_manifest.txt` (file, timeout, whether it needs `--fixed-fps 60`, how it counts
  as passed), always;
- the quest tests in `tests/ci_quests.txt` whose paths or test file changed; they join the required shards and
  block like the rest;
- as a warning only, the other test files the change touched (a new test, or an edited nightly one), in one
  `extra-tests` job that starts after `tests` has reported, so it never takes a runner the required shards need.

`tests/ci_shard.sh` splits the required tests into 4 shards on a pull request (6 in the nightly run) in a matrix by their measured length
(`tests/ci_timings.txt`): longest first, each to the shard with the least work so far, so all shards end at about
the same time. A test missing from that file counts as 15 s. Refresh it now and then from a run's logs (Actions >
a run > Download log archive, unpack, then `python3 tools/ci_timings.py <folder>/*.txt`); an outdated file only
makes the split less even, never wrong. The same script runs locally: `tests/ci_shard.sh blocking 0 1` runs the
required tests, `CI_QUESTS=all tests/ci_shard.sh blocking 0 1` adds every quest test and
`tests/ci_shard.sh nightly 0 1` runs the rest. To see what a branch would pick:
`git diff --name-only origin/main...HEAD | tests/ci_select.sh`.

Every job also restores the imported project (`.godot`) from the cache that pushes to main store
(`.github/actions/godot-setup`), so the import only handles what changed.

A test that fails is run once more. If it passes the second time it is reported as **flaky** (a warning on the run
and a line in the job summary) and does not block; a test that fails twice blocks. Treat every flaky report as a
bug in the test: seed the randomness (`seed(n)` in `_initialize`), wait for events or physics frames instead of
wall time, and read values such as `max_hit()` before the blow that trains a skill.

A pull request that changes only documentation (`docs/`, `balance/`, `*.md`) skips the shards; `tests` still
reports green (patch note fragments do not count as documentation: `tests/launcher.gd` checks them). A push to
main that merges a pull request ("... (#123)" or "Merge pull request") skips the shards too, because that
pull request was tested; the nightly run tests main as a whole.

**Editing a test list** (`tests/ci_manifest.txt`, `ci_scopes.txt`, `ci_quests.txt`, `ci_nightly.txt`, `ci_timings.txt`)
does not run the whole required list: only the tests whose lines you added or changed (plus the unscoped core
tests that always run) are picked. Changing a runner script (`tests/ci_*.sh`) or a workflow still runs everything.

**Quarantine:** a required test that fails twice on a pull request but also failed twice in the latest finished
nightly run on main does not block (a warning and a "Quarantined tests" line in the job summary). The nightly
shards keep the names of their failed tests as `failed-blocking-*` artifacts and `tests/ci_known_failing.sh` reads
them. So a test that is broken on main stops blocking every other pull request until the nightly run sees it pass
again; fix it anyway, the warning is easy to miss.

## Nightly: everything

Every night on main (and on a manual run: Actions > Tests > Run workflow, on any branch) the required shards run
every quest test too, and 8 `nightly-tests` shards run the nightly list and every test listed nowhere. The
nightly shards only warn. Check the nightly run now and then, and fix what it reports.

Tests listed in `tests/ci_on_demand.txt` (now `slime_siege.gd`) are skipped by every shard, because they are slow
or flaky in CI. They run only on demand: Actions > "On-demand tests" > Run workflow
(`.github/workflows/on_demand_tests.yml`, optionally with one file name), or locally with
`tests/ci_shard.sh on_demand 0 1`.

The workflow is called "Tests". Its last job, `tests`, gathers the shards: it passes only when every blocking
shard passed. That is the single check to require on pull requests, and the Windows build on main waits only
for it (never for the play-through or the browser export; the extra and nightly shards only warn). Adding or removing shards never
changes that name.

Patch notes do not conflict: every PR adds its own file in `docs/patch_notes.d/` and the release workflow
combines them with `docs/patch_notes.txt` (`tools/patch_notes.py`).

## Releases: Windows first

The Windows client is the main release, built by `.github/workflows/desktop.yml` ("Windows download") and
published on the release "windows" (Escape-Windows.zip, `version.json`, ...), which is what the launcher and
players use. A build costs runner time that the test shards need, so not every merge makes one:

- **Nightly:** after every green nightly run of the tests on main.
- **Big features:** a pull request labelled `big-feature` starts a build of its merge commit when it merges
  (`.github/workflows/big-feature-build.yml`).
- **By hand:** Actions > Windows download > Run workflow (optionally a commit; "force" builds again even if
  nothing changed).

A build is skipped when main is still the commit of the last published build. A pull request that touches the
launcher or the workflow itself builds the client as a download on its own run, nothing is published.

### Which label? (every PR is one of three kinds)

Pick the kind in the pull request (the checkbox in the PR template) and add the label only for the first:

1. **New feature:** a new system, area or mechanic that took a significant amount of work and that the player
   will want to play, even when it comes out of an existing thread (climbing is an example). The main pull
   request of a new thread with significant work always counts. Label it `big-feature`.
2. **Bug fix:** no label. It ships with the next build.
3. **Adjustment to an existing feature** (balance, looks, a tweak): no label, same.

When in doubt, do not label: the next nightly build ships it anyway.

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

1. **Require status checks to pass before merging**, with the single check `tests` (never `build`, `tests-shard (n)`, `extra-tests` or `nightly-tests (n)`).
2. **Require branches to be up to date before merging** ("strict" status checks). A pull request that is behind main
   then has to be updated and re-tested before it can merge. Or, better when several pull requests land at once,
   **Require merge queue**: GitHub merges each pull request on top of the queue and tests that result.

`web.yml` already listens to `merge_group`, so `tests` runs for queued merges.

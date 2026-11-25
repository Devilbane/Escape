#!/usr/bin/env bash
# Runs one shard of the headless tests, see .github/workflows/web.yml and docs/testing.md.
#   tests/ci_shard.sh blocking <shard> <shards>   the required tests: tests/ci_manifest.txt, plus the quest tests
#                                                 named in $CI_QUESTS (from tests/ci_select.sh; "all" runs them all)
#                                                 minus the ones named in $CI_SKIP (tests/ci_scopes.txt)
#   tests/ci_shard.sh extra <shard> <shards>      the tests named in $CI_EXTRA (changed test files that are not
#                                                 required; a failure is only a warning in CI)
#   tests/ci_shard.sh nightly <shard> <shards>    every test that is not required: tests/ci_nightly.txt and any
#                                                 tests/*.gd listed nowhere yet (the nightly run)
#   tests/ci_shard.sh on_demand <shard> <shards>  the tests in tests/ci_on_demand.txt, which general CI skips
# The tests are split by their measured length (tests/ci_timings.txt): longest first, each to the shard with the
# least work so far, so all shards end at about the same time. Runs all its tests, then fails if any failed.
# A failed test is run once more: passing on the retry makes it a reported flaky test, not a failure.
# A test that fails twice but is named in $CI_KNOWN (the required tests that failed in the latest nightly run on
# main, see tests/ci_known_failing.sh) is quarantined: reported as a warning, it does not block the pull request.
# Every test that fails twice is written to ci_logs/failed.txt (the nightly run keeps it as an artifact).
set -u
mode=${1:?blocking, extra, nightly or on_demand}; shard=${2:?shard number from 0}; shards=${3:?number of shards}
godot=${GODOT:-$HOME/godot/godot}
cd "$(dirname "$0")/.."

mkdir -p ci_logs
list=$(mktemp)
# The four columns the runner needs (file, timeout, fps, check) of a list's lines; quest lines carry their paths
# in the fifth column, which is dropped here.
columns() { grep -v '^#' "$@" | grep . | awk -F' [|] ' '{print $1" "$2" "$3" "$4}'; }
# A test listed in none of the files runs with these settings.
unlisted() { echo "$1 120 fixed passfail"; }
case "$mode" in
  blocking)
    columns tests/ci_manifest.txt > "$list"
    # Scoped tests (tests/ci_scopes.txt) that this change cannot affect, named in $CI_SKIP by tests/ci_select.sh.
    for sk in ${CI_SKIP:-}; do grep -v "^$sk " "$list" > "$list.2"; mv "$list.2" "$list"; done
    quests=${CI_QUESTS:-}
    if [ "$quests" = all ]; then columns tests/ci_quests.txt >> "$list"
    else for q in $quests; do columns tests/ci_quests.txt | grep "^$q " >> "$list"; done; fi;;
  on_demand) columns tests/ci_on_demand.txt > "$list";;
  extra)
    for n in ${CI_EXTRA:-}; do
      [ -f "tests/$n" ] || continue
      columns tests/ci_nightly.txt | grep "^$n " || unlisted "$n"
    done > "$list";;
  nightly)
    columns tests/ci_nightly.txt > "$list"
    for t in tests/*.gd; do
      n=$(basename "$t")
      case "$n" in play_all_levels.gd|profile_*.gd) continue;; esac
      grep -q "^$n " tests/ci_manifest.txt tests/ci_quests.txt tests/ci_nightly.txt tests/ci_on_demand.txt && continue
      unlisted "$n"
    done >> "$list";;
  *) echo "unknown mode $mode"; exit 2;;
esac

# Runs one test once; sets ok to 1 when it passed.
run_test() {
  flags=--headless; [ "$fps" = fixed ] && flags="--headless --fixed-fps 60"
  log=ci_logs/${name%.gd}.log
  timeout "$secs" "$godot" $flags -s "tests/$name" > "$log" 2>&1
  case "$check" in
    pass) ok=$(grep -q PASS "$log" && echo 1);;
    passfail) ok=$(grep -q PASS "$log" && ! grep -q FAIL "$log" && echo 1);;
    *) ok=$(grep -qF "${check//_/ }" "$log" && echo 1);;
  esac
}

# This shard's tests, in list order: number every line, give it its measured seconds (15 when unmeasured), deal
# them out longest first to the least loaded shard (ties by list order), keep this shard's lines.
mine=$(mktemp)
awk -v tf=tests/ci_timings.txt 'BEGIN { while ((getline l < tf) > 0) if (l !~ /^#/ && split(l, a, " ") == 2) w[a[1]] = a[2] }
  { print (($1 in w) ? w[$1] : 15), NR, $0 }' "$list" \
  | sort -k1,1nr -k2,2n \
  | awk -v n="$shards" -v k="$shard" '{ b = 0; for (s = 1; s < n; s++) if (load[s] < load[b]) b = s; load[b] += $1
      if (b == k) { $1 = ""; print substr($0, 2) } }' \
  | sort -k1,1n | cut -d' ' -f2- > "$mine"

fail=0; flaky=(); quarantined=()
while read -r name secs fps check; do
  start=$SECONDS
  run_test
  if [ -n "${ok:-}" ]; then echo "ok   $name ($((SECONDS - start))s)"
  else
    # A failed test gets one more try. If that passes, it is reported as flaky (a warning and a line in the
    # job summary) and does not block; a test that fails twice is a real failure.
    echo "::warning::tests/$name failed once, running it again"; tail -n 15 "$log"; cp "$log" "ci_logs/${name%.gd}.first.log"
    run_test
    if [ -n "${ok:-}" ]; then
      echo "FLAKY $name passed on the second try ($((SECONDS - start))s)"
      echo "::warning::tests/$name is flaky: it failed once and passed on the retry"
      flaky+=("$name")
    else
      echo "$name" >> ci_logs/failed.txt
      if [[ " ${CI_KNOWN:-} " == *" $name "* ]]; then
        echo "::warning::tests/$name did not pass (twice), but it already fails on main: quarantined, not blocking"; tail -n 15 "$log"
        quarantined+=("$name")
      else
        echo "::error::tests/$name did not pass (twice)"; tail -n 15 "$log"; fail=1
      fi
    fi
  fi
done < "$mine"
rm -f "$list" "$mine"
if [ ${#flaky[@]} -gt 0 ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### Flaky tests ($mode shard $shard)"; echo "Failed once and passed on the retry. Please make them deterministic:"; for f in "${flaky[@]}"; do echo "- \`$f\`"; done; } >> "$GITHUB_STEP_SUMMARY"
fi
if [ ${#quarantined[@]} -gt 0 ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### Quarantined tests ($mode shard $shard)"; echo "Failed twice here, but they already fail on main (latest nightly run), so they do not block:"; for f in "${quarantined[@]}"; do echo "- \`$f\`"; done; } >> "$GITHUB_STEP_SUMMARY"
fi
exit $fail

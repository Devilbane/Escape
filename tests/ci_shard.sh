#!/usr/bin/env bash
# Runs one shard of the headless tests, see .github/workflows/web.yml.
#   tests/ci_shard.sh blocking <shard> <shards>   the tests listed in tests/ci_manifest.txt
#   tests/ci_shard.sh extra <shard> <shards>      every other tests/*.gd (not blocking in CI)
# Shard k of n takes every n-th test, so slow and fast ones mix. Runs all its tests, then fails if any failed.
# A failed test is run once more: passing on the retry makes it a reported flaky test, not a failure.
set -u
mode=${1:?blocking or extra}; shard=${2:?shard number from 0}; shards=${3:?number of shards}
godot=${GODOT:-$HOME/godot/godot}
cd "$(dirname "$0")/.."

mkdir -p ci_logs
list=$(mktemp)
if [ "$mode" = blocking ]; then
  grep -v '^#' tests/ci_manifest.txt | grep . | awk -F' [|] ' '{print $1" "$2" "$3" "$4}' > "$list"
else
  for t in tests/*.gd; do
    n=$(basename "$t")
    case "$n" in play_all_levels.gd|profile_*.gd) continue;; esac
    grep -q "^$n " tests/ci_manifest.txt && continue
    echo "$n 120 fixed passfail"
  done > "$list"
fi

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

fail=0; i=0; flaky=()
while read -r name secs fps check; do
  if [ $((i % shards)) -eq "$shard" ]; then
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
        echo "::error::tests/$name did not pass (twice)"; tail -n 15 "$log"; fail=1
      fi
    fi
  fi
  i=$((i + 1))
done < "$list"
rm -f "$list"
if [ ${#flaky[@]} -gt 0 ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### Flaky tests ($mode shard $shard)"; echo "Failed once and passed on the retry. Please make them deterministic:"; for f in "${flaky[@]}"; do echo "- \`$f\`"; done; } >> "$GITHUB_STEP_SUMMARY"
fi
exit $fail

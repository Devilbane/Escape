#!/usr/bin/env bash
# Runs one shard of the headless tests, see .github/workflows/web.yml.
#   tests/ci_shard.sh blocking <shard> <shards>   the tests listed in tests/ci_manifest.txt
#   tests/ci_shard.sh extra <shard> <shards>      every other tests/*.gd (not blocking in CI)
# Shard k of n takes every n-th test, so slow and fast ones mix. Runs all its tests, then fails if any failed.
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

fail=0; i=0
while read -r name secs fps check; do
  if [ $((i % shards)) -eq "$shard" ]; then
    flags=--headless; [ "$fps" = fixed ] && flags="--headless --fixed-fps 60"
    log=ci_logs/${name%.gd}.log
    start=$SECONDS
    timeout "$secs" "$godot" $flags -s "tests/$name" > "$log" 2>&1
    case "$check" in
      pass) ok=$(grep -q PASS "$log" && echo 1);;
      passfail) ok=$(grep -q PASS "$log" && ! grep -q FAIL "$log" && echo 1);;
      *) ok=$(grep -qF "${check//_/ }" "$log" && echo 1);;
    esac
    if [ -n "${ok:-}" ]; then echo "ok   $name ($((SECONDS - start))s)"
    else
      echo "::error::tests/$name did not pass"; tail -n 15 "$log"; fail=1
    fi
  fi
  i=$((i + 1))
done < "$list"
rm -f "$list"
exit $fail

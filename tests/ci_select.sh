#!/usr/bin/env bash
# Picks the optional tests for one CI run from the files it changed (one path per line on stdin), see
# .github/workflows/web.yml and docs/testing.md. Prints two lines for $GITHUB_OUTPUT:
#   quests=<tests>  the tests in tests/ci_quests.txt whose test file or one of whose paths changed; they join the
#                   required shards
#   extra=<tests>   changed test files that are neither required nor a quest test (tests/ci_nightly.txt or not
#                   listed anywhere yet); they run once as a warning only
# Locally: git diff --name-only origin/main...HEAD | tests/ci_select.sh
set -u
cd "$(dirname "$0")/.."
mapfile -t changed
quests=(); extra=()

while IFS='|' read -r file _ _ _ paths _; do
  file=$(echo "$file" | xargs); [ -z "$file" ] && continue
  for f in "${changed[@]}"; do
    hit=; [ "$f" = "tests/$file" ] && hit=1
    for p in $paths; do [[ "$f" == $p ]] && hit=1; done
    [ -n "$hit" ] && { quests+=("$file"); break; }
  done
done < <(grep -v '^#' tests/ci_quests.txt | grep .)

for f in "${changed[@]}"; do
  case "$f" in tests/*.gd) ;; *) continue;; esac
  n=${f#tests/}
  case "$n" in */*|play_all_levels.gd|profile_*.gd) continue;; esac
  [ -f "$f" ] || continue
  grep -q "^$n " tests/ci_manifest.txt tests/ci_quests.txt tests/ci_on_demand.txt && continue
  extra+=("$n")
done

echo "quests=${quests[*]}"
echo "extra=${extra[*]}"

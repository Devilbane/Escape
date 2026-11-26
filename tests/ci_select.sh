#!/usr/bin/env bash
# Picks the optional tests for one CI run from the files it changed (one path per line on stdin), see
# .github/workflows/web.yml and docs/testing.md. Prints two lines for $GITHUB_OUTPUT:
#   quests=<tests>  the tests in tests/ci_quests.txt whose test file or one of whose paths changed; they join the
#                   required shards
#   skip=<tests>   required tests of tests/ci_scopes.txt that this change cannot affect; they are left out of the
#                   required shards (empty whenever shared code changed)
#   extra=<tests>   changed test files that are neither required nor a quest test (tests/ci_nightly.txt or not
#                   listed anywhere yet); they run once as a warning only
# Locally: git diff --name-only origin/main...HEAD | tests/ci_select.sh
set -u
cd "$(dirname "$0")/.."
mapfile -t changed
shopt -s extglob; set -f
base=${BASE:-origin/main}

# The test lists (tests/ci_*.txt) are not shared code: editing one runs only the tests whose lines were added or
# changed in it (their first column), never the whole list. Those names join the changed files.
for list in tests/ci_manifest.txt tests/ci_scopes.txt tests/ci_quests.txt tests/ci_nightly.txt; do
  printf '%s\n' "${changed[@]}" | grep -qx "$list" || continue
  while IFS= read -r line; do
    n=${line%% *}; n=${n%%|*}
    [ -f "tests/$n" ] && changed+=("tests/$n")
  done < <(git diff -U0 "$base"...HEAD -- "$list" 2>/dev/null | grep -E '^\+[^+]' | cut -c2- | grep -v '^#')
done
declare -A scope
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

# Scoped required tests (tests/ci_scopes.txt): skipped only when every changed file is known, i.e. matches the
# paths of some scoped test or is neutral. One unknown file (shared code) keeps the whole required list.
skip=()
known=1; hits=" "
neutral='scripts/lang/*|levels/*|assets/*|shaders/*|docs/*|balance/*|*.md|*.uid|tests/*'
# Looks and sounds: pictures, models, poses, lights, weather drawing and audio change what the player sees and hears,
# not how the game plays, so they never force the scoped tests (they run on a change to anything else).
neutral+='|scripts/sfx.gd|scripts/music.gd|scripts/soundscape.gd|scripts/*_sounds.gd|scripts/*_look.gd|scripts/*_looks.gd'
neutral+='|scripts/*_model.gd|scripts/*_models.gd|scripts/*_pose.gd|scripts/*_icon.gd|scripts/effects.gd|scripts/fog*.gd'
neutral+='|scripts/*_shadows.gd|scripts/cave_lights.gd|scripts/window_lights.gd|scripts/lightning_*.gd|scripts/snow_*.gd'
while IFS='|' read -r file paths; do
  file=$(echo "$file" | xargs); [ -z "$file" ] && continue
  scope[$file]="$paths"
done < <(grep -v '^#' tests/ci_scopes.txt | grep .)
for f in "${changed[@]}"; do
  [ -z "$f" ] && continue
  case "$f" in tests/ci_*.txt) continue;; tests/ci_*|tests/*/*) known=; break;; esac
  seen=
  for t in "${!scope[@]}"; do
    for p in ${scope[$t]}; do [[ "$f" == $p ]] && { seen=1; hits+="$t "; }; done
  done
  [ -n "$seen" ] && continue
  [[ "$f" == @($neutral) ]] || { known=; break; }
done
if [ -n "$known" ]; then
  for t in "${!scope[@]}"; do
    [[ "$hits" == *" $t "* ]] && continue
    for f in "${changed[@]}"; do [ "$f" = "tests/$t" ] && continue 2; done
    skip+=("$t")
  done
fi

echo "quests=${quests[*]}"
echo "skip=${skip[*]}"
echo "extra=${extra[*]}"

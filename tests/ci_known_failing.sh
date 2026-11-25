#!/usr/bin/env bash
# Prints (space-separated, on one line) the required tests that failed twice in the latest finished nightly run on
# main, from the failed-blocking-* artifacts its shards upload (.github/workflows/web.yml). A pull request that
# fails one of them too does not block on it (tests/ci_shard.sh, $CI_KNOWN). Best effort: prints nothing when the
# run, the artifacts or the gh CLI are not there. Needs GH_TOKEN and `actions: read`.
set -u
id=$(gh run list --workflow web.yml --event schedule --branch main --status completed --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null) || exit 0
[ -n "$id" ] || exit 0
dir=$(mktemp -d)
gh run download "$id" --pattern 'failed-blocking-*' -D "$dir" >/dev/null 2>&1 || exit 0
cat "$dir"/*/failed.txt 2>/dev/null | sort -u | tr '\n' ' '
echo

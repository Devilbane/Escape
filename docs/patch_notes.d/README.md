# Patch note fragments

Each pull request that changes something a player will notice adds ONE new file here, so no two
pull requests ever edit the same file and patch notes never cause merge conflicts.

- Name it after the change, lower case with dashes: `docs/patch_notes.d/slime-turns-on-you.txt`.
  Never reuse or edit another PR's file.
- Content: one or more lines starting with `- `, written for players, in English, one short line each.
  Lines starting with `#` are comments.
- A build ships ONLY the fragments added since the previous published build (the git tag `windows`),
  under "## New in this build": `python3 tools/patch_notes.py build <previous commit>`. Older entries
  are not repeated; the fragment files stay in the repo as the record.
- Folding (done by the maintainer now and then, not by feature PRs):
  `python3 tools/patch_notes.py fold "Heading"` moves all fragments into `docs/patch_notes.txt` as a new
  top section and deletes them.

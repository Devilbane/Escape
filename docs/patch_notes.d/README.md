# Patch note fragments

Each pull request that changes something a player will notice adds ONE new file here, so no two
pull requests ever edit the same file and patch notes never cause merge conflicts.

- Name it after the change, lower case with dashes: `docs/patch_notes.d/slime-turns-on-you.txt`.
  Never reuse or edit another PR's file.
- Content: one or more lines starting with `- `, written for players, in English, one short line each.
  Lines starting with `#` are comments.
- `tools/patch_notes.py` puts every fragment under "## Latest changes" at the top of the notes that ship
  (the release workflow does this; see `docs/patch_notes.txt` for the header and the history).
- Folding (done by the maintainer now and then, not by feature PRs):
  `python3 tools/patch_notes.py fold "Heading"` moves all fragments into `docs/patch_notes.txt` as a new
  top section and deletes them.

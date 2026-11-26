# Protecting the game's data and saves

Escape! is a single-player game, so this keeps honest players from changing loot, skills, heroes and
money by accident or by a quick edit. Someone who takes the game apart can still get round it; only a server
can stop that. Riddle answers are protected separately (`RiddleVault`).

## Signed saves (`scripts/sim/save_seal.gd`)

- Saved games (`user://spielstaende/platz_N.json`) and the hero training (`user://helden.json`) end in a line
  `#seal <hmac>`: an HMAC-SHA256 of the JSON text. An edited file no longer fits its seal and is **not loaded**
  (it stays on disk; the training file is copied to `helden.json.edited` before it is rewritten).
- The key is the repository secret `SEAL_KEY`. The Windows workflow writes it to `scripts/seal_secret.gd`
  (git-ignored) before the export, so it travels only inside the encrypted game data. A build without the
  secret (tests, the editor, a PR from a fork) seals and checks nothing, so no save is ever sealed with a key a
  later build does not know. **Keep the secret fixed:** changing it makes every sealed save count as edited.
- **Migration:** the first start of a build with the key seals every existing unsealed save once and writes
  `user://seal_migrated`. After that a file without a seal counts as edited. Nobody loses progress.

## Encrypted game data (`godot_templates.yml`, `desktop.yml`)

Godot encrypts the exported data (`Escape.pck`, and the pack inside the launcher) with a key that is built into
the engine, which needs a custom engine: the official templates cannot do it.

1. Add the repository secrets `PCK_KEY` (64 hex digits: `openssl rand -hex 32`) and `SEAL_KEY` (any long
   random text). Never print them.
2. Run **Godot templates** (Actions) once. It compiles the Windows engine with the key (about half an hour)
   and keeps it in the Actions cache. Run it again when `PCK_KEY` or the Godot version changes.
3. **Windows download** finds the cached engine, turns on `encrypt_pck`/`encrypt_directory` for the two Windows
   presets while exporting, and checks that no script text is readable in the pack. Without the secret or the
   cached engine it builds as before, with a warning in the run, and without the encrypted-data smoke test
   (the official Linux engine cannot read encrypted data).

`export_presets.cfg` itself stays unchanged in the repository.

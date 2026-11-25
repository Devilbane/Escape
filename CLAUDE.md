# Escape!: notes for Claude

A Godot 4.7 game (GDScript). Entry scene `scenes/main.tscn`, main logic in `scripts/game.gd`,
windows in `scripts/menus.gd`, the merchant window in `scripts/trade_window.gd`. Headless tests live
in `tests/` and run with `godot --headless -s tests/<name>.gd`.

## Before any UI work

Read the **`ux-ui` skill** at [`.claude/skills/ux-ui/SKILL.md`](.claude/skills/ux-ui/SKILL.md)
before designing, building, reviewing or changing anything the player sees or touches (windows,
HUD, pull-out menu, inventory, shops, compendium, buttons, labels, icons). Follow its rules and the
house style in its Part 2, and tick its checklist (Part 3) in the pull request.

The most important standing rule: expanding or collapsing a section (accordion, folding category,
tab, details card) must not reshape or condense the rest of the window.

## CI tests

A new test goes in one of three lists (rule in `docs/testing.md`, "What goes in the required check"):
`tests/ci_manifest.txt` blocks every PR and holds only fast, deterministic core logic (saves, combat, items and
trading, collisions and getting stuck, data checks); `tests/ci_quests.txt` holds a finished quest's or dungeon's
test with the paths it covers, and it runs only when a PR touches them; a manifest test whose feature lives in its own files also gets a line in `tests/ci_scopes.txt` (paths it covers; a PR skips it unless it touches them, shared code runs everything); `tests/ci_nightly.txt` holds looks,
screenshots, sounds, ambient life and timing-based simulations, which run every night. When in doubt, nightly.

## Language

Write messages, code comments, PR descriptions and docs in English. Player-facing strings are
written in German in the code and translated through `Lang` (`scripts/lang.gd`): every new string
needs an English entry in its feature's file in `scripts/lang/` (a new feature gets a new file, listed in
`Lang.PARTS`). They are merged into `Lang.EN`; run `tests/lang_keys.gd`, which fails when a German text is
in two files or a file is not listed.

## Map letters

Every letter a map in `levels/` uses is listed in `scripts/tiles.gd` (`Tiles.DUNGEON` for maps
built by `Level`, `Tiles.OUTDOOR` for the open-air map). Before using a new letter, claim it there,
then run `tests/tile_letters.gd`: it fails when a map uses an unlisted letter or when two things in
the code (a match arm, `Enemy.WILD_LETTERS`, `Animal.LETTERS`, ...) share one letter.

## Monster families

Every kind in `Enemy.KINDS` belongs to a family in `MonsterFamilies.KINDS` (`scripts/monster_families.gd`):
bandits, undead, ghosts, wildlife, fable or humans (the horrors fit anywhere). Every map in `levels/` names
the families that live there in its header, `monsters: undead, ghosts`. A new kind gets a family, and a
monster placed or spawned somewhere must belong to that map's families; `tests/monster_families.gd` checks both.

## Event bus

Features report what happened on the event bus, `Events.bus()` (`scripts/events.gd`), instead of
calling `game.gd` or each other: `Events.tell(text, colour)` for news, `Events.teach(entry)` for the
compendium, and signals such as `enemy_slain`, `quest_done` and `traded`. Who listens to what is
listed in one place, `Game._bus_links()`. A new cross-feature call should be a signal there.
`tests/events.gd` checks the wiring.

## Map workshop

The map editor is its own scene, `scenes/editor.tscn` (`scripts/level_editor.gd`, with `editor_*.gd` and
`level_map.gd`). It edits `levels/*.txt` through `LevelMap`, whose `validate()` must pass for every shipped
map (`tests/level_editor.gd`). A new tile letter also needs a group, a German name and an English entry in
`EditorPalette` (the test checks it). The digits are each map's own creations (`Creations`, header `custom:`).


## Mountain foot

Every rock tile of an Outdoor map gets a foot: lobes, mounds, an earth apron and small stones and tufts
(`scripts/mountain_foot.gd`, `MountainFoot`, called from `Outdoor` after `Mountains.build`), on open meadow and on scree
(`MountainFoot.OPEN`), the Notch Pass included. A new mountain needs nothing of its own: draw the rock `=` and the foot follows. Stones,
tufts and boulders lie outside the lobes and mounds; litter that lies on the ground (the fallen leaves, see
`SurfaceLife`) asks `MountainFoot.surface_at` for the height so it lies on top, not under. Climbing spots keep a
walkable lane of the spot's width and its neighbours (`MountainFoot.clear_fade`); `tests/foot_lobes.gd` checks it.

## Smooth motion

Physics interpolation is on, but the game's root turns it off and only bodies that move in
`_physics_process` (hero, `Enemy`, `Villager`, `Animal`, `Pet`, `Projectile`) turn it on, with
`SmoothMotion.follow_ticks(self)` in `_ready` (`scripts/smooth_motion.gd`). A new such body does the same.
Move those bodies only in physics ticks: a tween on one uses `set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)`,
and putting one somewhere new calls `reset_physics_interpolation()`. Anything moved per frame stays
uninterpolated. Something that follows the hero per frame uses `SmoothMotion.drawn_at(player)`.
`tests/smooth_motion.gd` checks it; `tests/profile_run.gd` and `tests/profile_nodes.gd` measure frame costs.

## Planted feet

Walks and runs play at the pace of their stride (`scripts/stride.gd`): `Stride.FEET` lists how fast each
animation's planted foot travels, measured from the bones, and `Stride.playback` turns a body's ground speed
into the animation's playback rate. A walker no faster than `Stride.top_speed` for a walk, or moved on to the
next gait with `Stride.gait`, never slides its feet. Humans rise onto their toes at each push-off
(`Stride.lift`). A new walking model or animation gets its rig and speed in `Stride`; `tests/stride.gd`
measures them again and checks every walker's speeds.

## Patch notes

The Windows launcher shows the patch notes while it downloads (the release workflow puts them into
`version.json` as `notes`). Never edit `docs/patch_notes.txt` in a feature PR: it clashes with every other PR.
When you change something a player will notice (a feature, a fix, a balance change), add ONE new file
`docs/patch_notes.d/<short-change-name>.txt` with one short English line `- text` (see `docs/patch_notes.d/README.md`).
`tools/patch_notes.py` combines the fragments with `docs/patch_notes.txt` at release time, and only the newest
two sections ship. `tests/launcher.gd` checks that the fragments parse and everything fits.
Every build's notes are archived in `docs/patch_history.json` (the compendium's patch notes page); the Windows
build adds to it, so never edit it in a feature PR.

## Windows builds and PR labels

A Windows build is made only after a green nightly run, by hand, or when a merged PR carries the `big-feature` label
(`.github/workflows/big-feature-build.yml`). Label a PR `big-feature` only for a new feature that took significant
work (or the main PR of a new thread with significant work); never a bug fix or an adjustment of an existing feature.
Details and the PR-template checkbox: `docs/testing.md`, "Which label?".

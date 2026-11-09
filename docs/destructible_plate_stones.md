# Destructible plate stones (design note, not built yet)

An idea for the block puzzles: the heavy stone becomes something monsters try to break, so a plate cannot
simply be solved in peace. Nothing here is implemented; this note says how it would fit and what to decide first.

## What exists today

- `StoneBlock` (`scripts/stone_block.gd`) with `heavy = true` is an old block of a puzzle room. The hero pushes it with E or
  drags it with the mouse, but never more than `Level.HEAVY_RANGE` (5 tiles) from its `home`. It is not kept in the bag.
- A `_` tile is a pressure plate (`Level._build_plate`). `_plate_pressed` checks whether any layer-0 block covers one of the
  plate's cells; `_check_plates` counts them and `_open_gates` sinks the iron gates (`|`) for good once every plate is pressed.
  A solved puzzle is remembered (`GATES_OPEN`), and so is where each heavy block was left (`heavy_key`).
- `Level.plates_out_of_reach()` (checked by `tests/level_editor.gd`) guarantees that every plate has its own block within 5 tiles.
- Maps using it today: 03 Das Labyrinth, 28 Die Schwefelgänge, 31 Die Aschenzinne, 34 Das Archiv. Map 38 has a `Q` but no plate.
- Blocks are not damageable. Monsters path around them (`_stone_cut`), and skeletons and bandits cannot climb.
- Precedent for monsters breaking things: slimes besiege `WallBrick`s of the village wall (`VillageWall.target_for`,
  `WallBrick.hurt`, `mend`). The state, hp bar and "breach" alarm already exist there.

## The idea in one sentence

The plate is far from the block's home, the way to it is guarded, and monsters attack the block while the hero pushes it.
The player has to escort it, and a destroyed block means fetching or making another.

## Rules (kept small)

1. **Stone health.** A heavy block gets a fixed HP (a flat number, like `WallBrick.MAX_HP`), shown as the same small bar the
   village wall uses and as cracks (`WallCracks`) at 66 % and 33 %. No armour, resistances or damage types. The hero's own
   hits never hurt it.
2. **Who attacks it.** Only monsters of a puzzle map's families that already attack walls, plus a new flag on the kinds meant to
   do it (start with skeleton brutes and orcs; archers and casters ignore it). A monster picks the block as target only when
   the hero is out of sight or farther away than the block, so the hero stays the priority and the fight is not a new system.
   It reuses the `_wall_target` idea in `Enemy` (walk up, strike on its normal timer, damage = its normal hit).
3. **Signposting.** The first time a block is hit, a news line (`Events.tell`) says "Monsters are smashing the block!", and a
   compendium entry (`Events.teach`) explains it. The block flashes when hit. A plate room says in its map `hint:` that the
   blocks are not safe.
4. **A broken block** leaves rubble (decoration only) and is gone. It never softlocks (see source below).
5. **Pressed plates stay safe.** Once the gates are open nothing matters any more, and the existing "solved stays solved"
   rule is unchanged. Optionally a block resting on a plate is immune, so the guarded part is only the way there.

## The stone source

Without a supply the puzzle could end in a dead end, so every destructible-block room needs a permanent source:

- A new map tile (a quarry or "block fountain" letter, claimed in `Tiles.DUNGEON`, with a group and names in `EditorPalette`).
  It spawns a fresh heavy block on a free cell next to it, at most one at a time, after a cooldown (say 60 s) once the last
  one is gone or has left the 5-tile range.
- The source is the block's new `home`, so the 5-tile leash (`heavy_in_range`) now means "far enough to be a journey, never
  more". That is the rule that makes "a distant plate" work: the source must lie within reach of the plate by chain, so either
  the leash is lifted to a longer range for source blocks, or several rest stops are placed on the way. Decide this first.
- `plates_out_of_reach()` must learn the source tile, so the editor check still proves every plate can be solved.
- The source is saved like the plates (a map flag), not per block; only blocks that exist are saved with `taken`.

## Where it would be used

- **28 Die Schwefelgänge** is the natural first one: skeleton archers already hold the guard hall, the gate is the way down.
- **34 Das Archiv** (undead and ghosts): the gate leads to the archivist, so a strong place for a long, guarded push.
- **31 Die Aschenzinne**: the block already sits with a hidden wall; a second route would add a choice rather than replace it.
- **03 Das Labyrinth**: keep as it is. It is an early puzzle and teaches the push controls (plain blocks, no attackers).
- A choice in keeping with the project rules: a block can be pushed and guarded (safe but slow), or the hero can clear the
  guards first and push in peace (fast but risky). Both are clear, and neither adds a new system.

## Risks

- **Frustration.** Losing a block after a long push is punishing. The source and the respawn cooldown, a clear hit warning,
  and enough HP that one slip is survivable all matter. Offer the easy setting by leaving a map's block indestructible.
- **Combat complexity.** The project wants simple combat. Keep to one HP number, one target rule and one signpost; no new
  buttons, no repair action for the hero.
- **Pathing.** `_stone_cut` already changes the map for monsters. A block that is destroyed has to update it
  (`refresh_stone_paths`), and monsters leaning on a block must not trap themselves behind it.
- **Perf.** Monsters scanning for blocks every tick. Check it only when they have no hero target, and only on maps that have a source.
- **Saves.** `heavy_key` stores the cell of each block; a gone block and a pending respawn need their own marker.
- **Editor and tests.** `LevelMap.validate()`, `plates_out_of_reach`, `tests/stone_puzzle.gd` and `tests/tile_letters.gd` all need updates.

## Decisions (from the project owner, 9 November 2026)

1. **A separate kind of room.** The block puzzles in maps 03, 28, 31 and 34 stay as they are. The new mechanic gets its own test room first.
2. **Every monster can attack the block**, not a chosen few. (The hero stays their priority target, see rule 2 above.)
3. **One map, a long way apart.** The stone source and the plate are in the same map or dungeon, far from each other, so the hero has to
   push the block the whole way and protect it on the journey. This replaces the 5-tile leash for source blocks: a block from the source
   is free to travel all the way, and `plates_out_of_reach()` must instead check that a walkable route from the source to the plate exists.
4. **A block on a plate is immune.** Only the way there is dangerous.
5. **The source can give more blocks, but the hero cannot store them.** Each one has to be pushed separately, so a lost block costs one trip
   and never the puzzle. The source keeps spawning while it has free room next to it (cooldown as above); there is no bag, quick bar or
   carrying of blocks.
6. **The test room is the cheapest one to check the mechanic:** a new small map for the feature alone (undead family), one long corridor
   with a bend: the source at one end, the plate and its gate at the other, and two or three melee monsters on the way. A hit-points number
   low enough to see a block break within a minute makes the test quick. It needs no story or loot: one chest behind the gate is enough.

## Still to decide when it is built

- The block's HP and the damage a monster does to it (a balance pass with the combat sheet in `balance/`).
- The source's cooldown and how many blocks may stand at once.
- The name of the new tile letter for the source (claim it in `Tiles.DUNGEON` first).

# The Ashen Spire (Sonnet version)

A surface-and-underground area for a hero of level 18 to 20. The goal is to steal the **Grimoire of the Quiet Flame**
from the sanctum at the bottom, which teaches **Arcane Energy** (key `Z`: an arcane bolt).

## Where it is

The gate is a ruined stone arch (`<` on the open-air map) in the high valley of the eastern mountains, beside mine III.
Five floors, chained like the mines (`building: spire1` .. `spire5`, headers `down:` / `up:`). Floor 1 is open ground
(`theme: zinne`), the rest are cellars. Everything is tuned as one area, `zinne`, level 18 to 20 (`HeroLevel.AREAS`).

## What the way down asks for

| Floor | Needs |
| --- | --- |
| 1 Aschenzinne (courtyard) | fighting (orcs, wolves, archers, skeletons), the **block puzzle** (two blocks on two plates open the iron gate), a **secret wall** in front of the way down |
| 2 Zisterne (cistern) | **sneaking**: dark hall, armoured guardians with 20 times a skeleton's life that fall to a single stab in the back (one carries the key), **hidden bed** (safe spot 1) |
| 3 Räderwerk (clockwork) | **timed jumps** over eight blade sweepers with archers and mages shooting along the corridors, a **crate** (carried through the second gauntlet) to climb the **ledge**, **supply cache** (healing potions) and **anvil** (mends gear), **sub boss 1** Gorrak the Gatebreaker |
| 4 Archiv (archive) | **prisoner** Brother Orlan (quest: a healing potion for his secret), second block puzzle, **hidden bed** (safe spot 2), **sub boss 2** Archivist Veth |
| 5 Allerheiligste (sanctum) | sneak the guardians, third sweeper gauntlet, crate + ledge, the **grimoire** on its lectern (stealing it wakes the floor), optional **boss** Ashkaran's Shade behind an iron door, **hidden hatch** (a ladder back up to the courtyard, no teleport) |

Every floor has `respawn: ja`: a fallen monster comes back after 8 world hours (400 s) while the hero is out of sight
and 30 m away, or when they come back to the floor later (sleeping counts). Levers on these floors always work
(`sure: ja`): the hero only has to stand by the right torch.

## New pieces of the engine

- `AshLedge` (`a`): a block three crates high; only a crate or a stone block as a step gets a hero over it.
- `AshBlades` (`z`): a low blade turning round a post; jump it. A hit costs 2 + place level / 4 life, a deft hero can dodge.
- `p`: a loose crate to carry (E) and set down (Q).
- `I` lectern with the grimoire, `*` supply cache, `!` anvil, `;` hatch (`AshSpire`).
- Header `respawn:`, `sure:`, `hatch:`; `Level.world_hours` is the world's clock in hours (kept in the saved game).
- `AshBolt` and `AshSpire.cast`: the spell. Skill "Arkane Energie" (`Training.CRAFTS "magie"`), power `4 + 2 per level + (Intelligenz - 10) / 2`,
  cooldown `4 s - 0.25 s per level` (at least 1.5 s). It pierces armour, not the guardian's plate.

Test: `godot --headless --fixed-fps 60 -s tests/ash_spire.gd`.

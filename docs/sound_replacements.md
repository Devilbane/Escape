# Sound replacements

Two bought packs were added: **Anime Combat Sounds** (The Sound Guild) and **Fantasy Ambience Sounds Pack V2**.
`tools/make_pack_sounds.py` builds the files; each keeps the name of the sound it replaced, so no code changed.

## Applied in this change

| Sound (file in `assets/sounds/`) | Old source | New source |
|---|---|---|
| `chop.wav` (woodcutters, treasure-map digging) | synthesised | Fantasy Ambience: `Chopping_Wood_Without_Whoosh_Loop_01` (one stroke) |
| `village_bell.wav` | Ivo Vicic church bells (Soniss) | Fantasy Ambience: `Church_Bells_Loop_01` (first 9.5 s) |
| `rain.ogg` | synthesised 8 s loop | Fantasy Ambience: `Rain_Medium_Loop_01` (44 s loop) |
| `rain.ogg`, `rain_light.ogg`, `rain_heavy.ogg` | one rain loop | Fantasy Ambience `Rain_Light/Medium/Heavy_Loop_01`, mixed by how hard it rains |
| `sword_swing_0..2` | CC0 mix | `Anime_Combat_Whoosh_01..03` |
| `sword_sweep_0..1` | CC0 mix | `Anime_Whirlwind_High_Pitch_01..02` |
| `sword_hit_0..3` | CC0 mix | `Anime_Slash_01_Variation_01/02`, `Anime_Slash_02`, `Anime_Slash_03` |
| `sword_heavy_0..2` | CC0 mix | `Anime_Combat_Hit_01..03` |
| `sword_vital_0..1` | CC0 mix | `Anime_Critical_Damage_01..02` |
| `sword_sneak_0..1` | CC0 mix | `Anime_Attack_Critical`, `Anime_Impact_High_Pitch_Critical` |
| `sword_glance_0..2` | CC0 mix | `Anime_Clash_01_Shorter`, `Anime_Clash_03_Shorter`, `Anime_Clash_02` |
| `axe_swing_0..2` | CC0 mix | `Anime_Whoosh_04..06` |
| `axe_sweep_0..1` | CC0 mix | `Anime_Whirlwind_01..02` |
| `axe_hit_0..3` | CC0 mix | `Anime_Low_Impact_01..04` |
| `axe_heavy_0..2` | CC0 mix | `Anime_Combat_Hit_04`, `Anime_Combat_Hit_05`, `Anime_Hit` |
| `axe_vital_0..1` | CC0 mix | `Anime_Critical_Damage_03`, `Anime_Wound_01` |
| `axe_sneak_0..1` | CC0 mix | `Anime_Wound_02`, `Anime_Punch_Hard` |
| `axe_glance_0..2` | CC0 mix | `Anime_Armour_Impact`, `Anime_Sword_&_Shield_Fight_Impact_01..02` |
| `hit.wav` | synthesised | `Anime_Small_Impact` |
| `swing.wav` | synthesised | `Anime_Whoosh_Attack` |
| `throw.wav` | synthesised | `Anime_Whoosh_Unarmed_Combat_01` |
| `hurt.wav` | synthesised | `Anime_Punch_Normal` |
| `magic.wav` | synthesised | `Anime_Aggressive_Spell_01` |

Left as they were: `bow_*` (crossbow recordings, the pack has no bow), the comic words `word_*` and the hero's cries `voice_*`.

## Candidates, not applied yet

Old and new files to listen to are in the project folder `escape/sound-replacements/candidates/` (`<name>__old` and `<name>__new_<pack file>`).

| Old file | Where it plays | Possible new sound |
|---|---|---|
| `anvil.wav` | smith's hammering | Fantasy Ambience `Blacksmith_Loop_01` |
| `rumble.wav` | quakes, falling rubble | Fantasy Ambience `Rockfall_Loop_01` (now used as the mine soundscape, not for the rumble) |
| `level_done.wav` | level cleared | `Anime_Energy_Up_02` |
| `loot_epic.wav` | epic loot fanfare | `Anime_Power_Up` |
| `loot_godborn.wav` | god-born loot fanfare | `Anime_Energy_Up_03` |
| `secret.wav` | secret found | `Anime_Movement_Teleport_01` |
| `drink.wav` | drinking a potion | `Anime_Bubbly_Sound_01` |
| `bones.wav` | bones breaking | `Anime_Destruction_07` |
| `ui_click.wav` | button click | `Anime_Hitmark_03` |

Applied pairs (old and new) are in `escape/sound-replacements/applied/`.

## Ambient soundscapes (new, `scripts/soundscape.gd`)

Every loop is cut to one loudness, mono, 24 kHz ogg, and fades in and out over 3 seconds. Above ground the mix follows where the hero stands, the hour and the rain; below ground each floor has one loop picked by its map header (and its name, so a floor always sounds the same). Rooms and houses keep the old cave air.

| Place or condition | Loop (pack file) |
|---|---|
| Village by day | `amb_village_day` (`Village_Loop_No_Chatter_No_ChurchBell_01`) |
| Village by night | `village_night` (`Village_Night_Loop_01`) |
| Near the market and the paved square, by day | `amb_townspeople` (`Townspeople_Chatter_Loop_01`) |
| Near the smithy, by day | `amb_blacksmith` (`Blacksmith_Loop_01`) |
| Near fields and the windmill, by day | `amb_farm` (`Farm_Loop_01`) |
| Near a campfire (bandit pass) | `amb_fire_camp` (`Fire_Loop_01`) |
| Woods by day | `amb_forest_day` (`Forest_Loop_01`), with a little `amb_forest_deep` (`Forest_Loop_02`) |
| Woods by night | `amb_forest_night` (`Enchanted_Forest_Loop_01`) |
| Light, steady, heavy rain | `rain_light`, `rain`, `rain_heavy` |
| Dungeon floors (cells, crypt, labyrinth, vault ...) | `amb_dungeon_0..2` (`Dungeon_Loop_01..03`) |
| Caves: dragon's lair, bone and rock walls, spider hole, queen's nest, hidden grotto, pale depths | `amb_cave_0..2` (`Cave_Loop_01..03`) |
| Copper mine, dwarven delve (themes `kupfer`, `zwerge`) | `amb_mine_0..1` (`Rockfall_Loop_01..02`) |
| Crystal grotto (`kristall`) | `amb_magic_1` (`Magical_Aura_Loop_02`) |
| Ember tunnels and the mountain's heart (`glut`) | `amb_fire_glow` (`Fire_Loop_02`) |
| Ancient halls (`uralt`) | `amb_astral_0..1` (`Astral_Plane_Loop_01..02`) |
| Ashen Spire floors (`zinne`) | `amb_magic_0` (`Magical_Aura_Loop_01`) |
| Sternhall courtyard (`sternhof`, open sky) | `amb_forest_deep` (`Forest_Loop_02`) |
| Houses, inns, shops | none (old cave air) |

Not used: `Forest_Burning_Loop_01` (nothing burns in the game), `Chopping_Wood_With_Whoosh_Loop_01` (the single chop covers it), `Church_Bells_Loop_01` (made into the bell), `Village_Loop_01` and `Village_Loop_No_Chatter_01` (they contain a bell and chatter, covered by the day loop plus the market layer).

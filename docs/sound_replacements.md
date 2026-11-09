# Sound replacements

Two bought packs were added: **Anime Combat Sounds** (The Sound Guild) and **Fantasy Ambience Sounds Pack V2**.
`tools/make_pack_sounds.py` builds the files; each keeps the name of the sound it replaced, so no code changed.

## Applied in this change

| Sound (file in `assets/sounds/`) | Old source | New source |
|---|---|---|
| `chop.wav` (woodcutters, treasure-map digging) | synthesised | Fantasy Ambience: `Chopping_Wood_Without_Whoosh_Loop_01` (one stroke) |
| `village_bell.wav` | Ivo Vicic church bells (Soniss) | Fantasy Ambience: `Church_Bells_Loop_01` (first 9.5 s) |
| `rain.ogg` | synthesised 8 s loop | Fantasy Ambience: `Rain_Medium_Loop_01` (44 s loop) |
| `village_night.ogg` (new) | none | Fantasy Ambience: `Village_Night_Loop_01`, fades in at night on the open ground (4 s), out at dawn or underground |
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
| `ambience.ogg` | endless cave ambience | Fantasy Ambience `Cave_Loop_01` or `Dungeon_Loop_01` |
| `rain.ogg` | rain (now Medium) | `Rain_Light_Loop_01` or `Rain_Heavy_Loop_01` for other weather strengths |
| `anvil.wav` | smith's hammering | Fantasy Ambience `Blacksmith_Loop_01` |
| `rumble.wav` | quakes, falling rubble | Fantasy Ambience `Rockfall_Loop_01` |
| `level_done.wav` | level cleared | `Anime_Energy_Up_02` |
| `loot_epic.wav` | epic loot fanfare | `Anime_Power_Up` |
| `loot_godborn.wav` | god-born loot fanfare | `Anime_Energy_Up_03` |
| `secret.wav` | secret found | `Anime_Movement_Teleport_01` |
| `drink.wav` | drinking a potion | `Anime_Bubbly_Sound_01` |
| `bones.wav` | bones breaking | `Anime_Destruction_07` |
| `ui_click.wav` | button click | `Anime_Hitmark_03` |

Applied pairs (old and new) are in `escape/sound-replacements/applied/`.

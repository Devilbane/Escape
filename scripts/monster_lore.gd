class_name MonsterLore
extends RefCounted
## Monster knowledge: the hero counts how many of each kind of monster they
## have slain, and the more they know a kind, the likelier a blow finds one
## of its vital points.
##
## A vital hit never rolls for damage: it deals VITAL_FACTOR times the
## hardest blow the hero can deal (see Player.vital_damage). On top it may
## slow the monster's attacks for the rest of the fight (SLOW_CHANCE, see
## Enemy.cripple) and make it bleed (BLEED_CHANCE, see Enemy.bleed).
##
## The chance follows RANKS, a few named steps that are easy to read in the
## compendium ("Monster lore" page): it never goes past CAP. Sneak attacks
## are separate: a stab in the back is never a vital hit as well.
##
## The counts are kept like Factions' favour: one static table for the game,
## saved and loaded with it, and filled from the event bus (enemy_slain, see
## Game._bus_links).

## [kills needed, chance of a vital hit, German rank name], from the first
## step to the last. The last chance is the cap.
const RANKS := [
	[0, 0.0, "Unbekannt"],
	[5, 0.05, "Bekannt"],
	[10, 0.10, "Kundig"],
	[25, 0.20, "Erfahren"],
	[50, 0.30, "Kenner"],
	[100, 0.40, "Meister"],
	[200, 0.50, "Schlächter"],
]
## The highest chance of a vital hit, whatever the count.
const CAP := 0.5
## A vital hit deals this many times the hero's hardest blow.
const VITAL_FACTOR := 2
## The chance that a vital hit slows the monster's attacks for the rest of
## the fight, and how much longer it then needs between attacks.
const SLOW_CHANCE := 0.3
const SLOW_FACTOR := 1.5
## The chance that a vital hit makes the monster bleed, whatever the weapon:
## as much life as the hit cost, bled away as Bleeding tells.
const BLEED_CHANCE := 0.3
## The colour of the words over a monster struck in a vital point, and of
## the compendium's numbers: a warm amber, apart from the red damage
## numbers and the sneak attack's crimson.
const VITAL_COLOR := Color(1.0, 0.62, 0.2)

## Monster kind -> how many of it the hero has slain.
static var kills := {}


## How many of this kind the hero has slain.
static func kill_count(kind: String) -> int:
	return int(kills.get(kind, 0))


## The index into RANKS for this many kills.
static func rank_for(count: int) -> int:
	var rank := 0
	for i in RANKS.size():
		if count >= int(RANKS[i][0]):
			rank = i
	return rank


static func rank_of(kind: String) -> int:
	return rank_for(kill_count(kind))


## The German name of a rank (see Lang).
static func rank_name(rank: int) -> String:
	return RANKS[clampi(rank, 0, RANKS.size() - 1)][2]


## The chance (0..CAP) that a blow at a monster of this kind is a vital hit.
static func vital_chance(kind: String) -> float:
	return minf(CAP, float(RANKS[rank_of(kind)][1]))


## Kills still needed for the next rank, or 0 at the last one.
static func kills_to_next(kind: String) -> int:
	var rank := rank_of(kind)
	if rank >= RANKS.size() - 1:
		return 0
	return int(RANKS[rank + 1][0]) - kill_count(kind)


## A roll for a vital hit on a monster of this kind.
static func roll_vital(kind: String) -> bool:
	var chance := vital_chance(kind)
	return chance > 0.0 and randf() < chance


## The German name of a monster kind, for the compendium and the news.
static func monster_name(kind: String) -> String:
	return Creations.MONSTER_NAMES.get(kind, kind)


## How many percent of the way to the next rank one more kill takes the hero
## (0 at the last rank), e.g. 20 at "Unbekannt" and 1 at "Meister".
static func gain_percent(kind: String) -> float:
	var rank := rank_of(kind)
	if rank >= RANKS.size() - 1:
		return 0.0
	return 100.0 / float(int(RANKS[rank + 1][0]) - int(RANKS[rank][0]))


## How many percent of the way to the next rank the hero is with this many kills
## (0 at the last rank); the whole part is the lore value the hero sees.
static func progress_percent(count: int) -> float:
	var rank := rank_for(count)
	if rank >= RANKS.size() - 1:
		return 0.0
	var start := float(int(RANKS[rank][0]))
	return 100.0 * (float(count) - start) / (float(int(RANKS[rank + 1][0])) - start)


## The hero slew a monster of this kind (the event bus's enemy_slain). A brief
## word over the hero's head tells the gain ("Skeleton lore +5%"), or the new
## rank when one is reached; the event log only gets one explanation, with
## the very first kill (Events.gain, Events.found).
static func on_hero_kill(kind: String) -> void:
	if kind == "":
		return
	var first := known_kinds().is_empty()
	var before := rank_of(kind)
	var old_whole := floori(progress_percent(kill_count(kind)))
	kills[kind] = kill_count(kind) + 1
	var new_whole := floori(progress_percent(kill_count(kind)))
	var after := rank_of(kind)
	var label := Lang.t(monster_name(kind))
	if after > before:
		Events.gain(Lang.t("%s-Kunde: %s (%d %% Schwachstellen)") % [label, Lang.t(rank_name(after)), roundi(vital_chance(kind) * 100.0)], VITAL_COLOR)
		Events.teach(LEARN)
	elif new_whole > old_whole:
		# Only a new whole number is worth a word; a gain that crosses several
		# shows the new value once.
		Events.gain(Lang.t("%s-Kunde %d %%") % [label, new_whole], VITAL_COLOR)
	if first:
		Events.found(Lang.t(EXPLAIN), VITAL_COLOR)


## Said once in the event log, at the very first kill.
const EXPLAIN := "Monsterkunde: Mit jedem besiegten Monster einer Art wächst deine Kunde von ihm. Die Zahl über deinem Kopf zeigt den Fortschritt zur nächsten Stufe."


## What the compendium learns the first time the hero gets to know a kind.
const LEARN := "Monsterkunde: Je mehr Monster einer Art du besiegst, desto öfter triffst du ihre Schwachstellen (bis zu 50 %). Ein solcher Treffer würfelt nicht: Er macht doppelt so viel wie dein härtester Schlag, und manchmal blutet das Monster danach oder greift für den Rest des Kampfes langsamer an. Alles steht im Kompendium (H) unter „Monsterkunde“."


## The kinds the hero has slain at least once, most kills first.
static func known_kinds() -> Array:
	var known: Array = kills.keys().filter(func(k): return kill_count(k) > 0)
	known.sort_custom(func(a, b):
		return kill_count(a) > kill_count(b) or (kill_count(a) == kill_count(b) and str(a) < str(b)))
	return known


static func clear() -> void:
	kills.clear()


## What is kept in the saved game: only plain values.
static func for_save() -> Dictionary:
	return kills.duplicate()


## Back from the saved game; older saved games start knowing nothing.
static func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	for k in saved:
		if (saved[k] is int or saved[k] is float) and int(saved[k]) > 0:
			kills[str(k)] = int(saved[k])

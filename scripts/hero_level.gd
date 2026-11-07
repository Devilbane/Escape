class_name HeroLevel
extends RefCounted
## The hero's level (Heldenstufe), 1 to MAX, earned with experience (XP).
##
## XP comes from monsters the hero fells, villagers' tasks, wishes, bounties
## and riddles (block-pushing puzzles, secret rooms, wall writings, the
## dwarves' rune tablets). The yardstick is time: one fair fight is worth
## about a minute of play, and a task pays what fighting monsters of its
## place's level would earn in the minutes it likely takes.
##
## A monster's level says which hero it is a fair fight for: a hero of that
## level, in gear that suits the level (EXPECTED), loses at most FAIR_SHARE of
## their life in a fight with it alone. It is worked out from the monster's
## real numbers when it falls (depth, elite, night and worn gear included);
## FIXED gives the bosses and the guardians a level of their own.
##
## A level-up gives (see Player): +1 Leben, +1 Konstitution every
## CON_EVERY levels, one point for Stärke, Geschick or Intelligenz every
## POINT_EVERY levels (the player picks on the character page) and +1 % Tempo
## every SPEED_EVERY levels up to SPEED_TOP. Attributes and skills still grow by use; level
## points come on top.
##
## Level and XP belong to the hero's name and are kept with the training
## (see Training.save_hero), from one run to the next.

const MAX := 50
## The world is made for heroes up to this level: the deep mine, the Great
## Old One's hoard and the bosses are its top (see AREAS and FIXED). The
## levels above it are the hero's own growth: they give the same rewards
## (but no more Tempo, see SPEED_TOP), the monsters of the top areas keep
## paying full XP (see low_factor) and the character page measures the odds
## against the world's strongest (see measured). Monsters are rated up to
## MAX, so a place made later for higher levels (or a strong monster from
## the map workshop) is worth it; raise WORLD_TOP with such a place.
const WORLD_TOP := 20
## XP for one level is STEP times the level the hero has now: 100 from level
## 1 to 2, 1900 from 19 to 20, 4900 from 49 to 50.
const STEP := 100
const CON_EVERY := 5
const POINT_EVERY := 3
const SPEED_EVERY := 2
const SPEED_PER_STEP := 0.01
## The last level that adds Tempo (+10 % in all): faster still would make
## the fights too easy to dodge.
const SPEED_TOP := 20
## The attributes a level point can go into.
const POINT_ATTRIBUTES := ["staerke", "geschick", "intelligenz"]

## XP for felling a monster of level L is KILL_XP * (L + 1); a boss gives
## BOSS_FACTOR times that. A task pays the same per minute.
const KILL_XP := 5
const BOSS_FACTOR := 5
## Anything more than LOW_GAP levels below the hero gives LOW_STEP less per
## further level, but never less than LOW_FLOOR of its XP.
const LOW_GAP := 3
const LOW_STEP := 0.2
const LOW_FLOOR := 0.1

## A fair fight costs at most this share of the hero's life. The hero swings
## once every SWING seconds (Player.AUTO_MELEE_INTERVAL).
const FAIR_SHARE := 0.4
const SWING := 0.8

## Monsters whose level is set by hand: the guardian falls only to a stab in
## the back, and the bosses are long fights made for dodging.
const FIXED := {"waechter": 3, "hauptmann": 9, "drache": 11, "bergkoenig": 20, "grosser_alter": 20, "spinnenkoenigin": 11}
const BOSSES := ["hauptmann", "drache", "bergkoenig", "spinnenkoenigin"]

## The areas of the world and the levels they are made for. A monster in an
## area is balanced to fit it (see Enemy and area_target): its natural level,
## anywhere from from[0] to from[1], is spread over min..max, and one that is
## stronger than the area's top is toned down to it. The dungeon is not lifted: its floors go from level 1 to 5 by
## their own depth, so the hero leaves the crypt at about level 5. The areas
## after it lead up to about level 15, and the deep mine is the top, 16 to 20
## (WORLD_TOP).
## "name" is for the compendium and the docs.
## The strongest a monster of the dungeon's floors may be: one whose rolled
## gear lifts it higher is toned down to it (see Enemy._fit_area).
const DUNGEON_TOP := 7
const AREAS := {
	"dorf": {"name": "Dorf und Friedhof", "min": 5, "max": 7, "from": [1, 6]},
	"pass": {"name": "Räuberpass", "min": 5, "max": 7, "from": [2, 5]},
	"senke": {"name": "Wolfssenke", "min": 6, "max": 8, "from": [4, 6]},
	"loecher": {"name": "Unheimliche Löcher", "min": 8, "max": 10, "from": [4, 8]},
	"hoehle": {"name": "Drachenhöhle", "min": 9, "max": 11, "from": [3, 6]},
	"berge": {"name": "Bergstraße und Hochtal", "min": 10, "max": 12, "from": [7, 13]},
	"mine1": {"name": "Kupfergrube", "min": 11, "max": 13, "from": [3, 13]},
	"mine2": {"name": "Kristallgrotte", "min": 13, "max": 15, "from": [4, 13]},
	"mine3": {"name": "Zwergenbinge, Glutstollen und Herz des Berges", "min": 16, "max": 19, "from": [3, 13]},
	"uralt": {"name": "Hort des Großen Alten", "min": 17, "max": 19, "from": [3, 13]},
	"zinne": {"name": "Aschenzinne und ihre Keller", "min": 18, "max": 20, "from": [3, 13]},
	"sternhall": {"name": "Sternhall", "min": 18, "max": 20, "from": [3, 13]},
}
## Which area a building (Level.building) belongs to.
const BUILDING_AREAS := {
	"b": "dorf", "^": "dorf", "loch1": "loecher", "loch2": "loecher", "loch2b": "loecher", "loch3": "loecher", "grotte": "senke",
	"E": "hoehle", "E2": "hoehle", "E3": "hoehle", "[": "berge", "mine1": "mine1", "mine2": "mine2",
	"mine3": "mine3", "mine3b": "mine3", "mine3c": "mine3",
	"uralt1": "uralt", "uralt2": "uralt", "uralt3": "uralt",
	"spire1": "zinne", "spire2": "zinne", "spire3": "zinne", "spire4": "zinne", "spire5": "zinne",
	"stern1": "sternhall", "stern2": "sternhall", "stern3": "sternhall", "stern4": "sternhall",
}

## Every task and how long it likely takes: minutes and the level of the
## place where it is done. Villagers' tasks and wishes by Quests id, bounties
## by Bounties id ("bounty:" in front).
const TASKS := {
	"raeuberplage": [10, 6], "dolche": [10, 6], "schlaeger": [8, 7], "wilderer": [6, 5],
	"hauptmann": [15, 9], "brief": [3, 5], "kuerbis": [3, 5], "wasser": [3, 5], "versoehnung": [4, 5],
	"wunsch_klingen": [10, 3], "wunsch_blocken": [10, 3], "wunsch_ruestung": [12, 5],
	"wunsch_aexte": [8, 7], "wunsch_werfen": [8, 5], "wunsch_schleichen": [8, 6],
	"bounty:woelfe": [6, 6], "bounty:spinnen": [6, 6], "bounty:untote": [8, 5],
	"bounty:orks": [6, 7], "bounty:halsabschneider": [6, 6], "bounty:wilderer": [6, 5],
	"bounty:schlaeger": [6, 7], "bounty:yeti": [8, 8], "bounty:bestien": [10, 7],
	"sternhall_alrik": [40, 19],
}
## Riddles: minutes each takes; they are done where the hero stands.
const RIDDLES := {"puzzle": 6, "secret": 3, "writing": 1, "rune": 5}
## A hidden trap spotted (see Traps) is worth this many minutes at its place.
const TRAP_MINUTES := 0.5
## A task nobody listed above: this long, in the village.
const TASK_MINUTES := 5
const VILLAGE_LEVEL := 5


## All the XP it takes to reach `level` from level 1.
static func total_for(level: int) -> int:
	return STEP * level * (level - 1) / 2


## The level reached with `xp` in all.
static func level_for(xp: int) -> int:
	var level := 1
	while level < MAX and xp >= total_for(level + 1):
		level += 1
	return level


## XP earned within the current level, and what the whole level takes
## (0 at MAX).
static func progress(xp: int) -> Vector2i:
	var level := level_for(xp)
	if level >= MAX:
		return Vector2i(xp - total_for(MAX), 0)
	return Vector2i(xp - total_for(level), STEP * level)


## What levels give, from level 1 up to `level`.
static func life_bonus(level: int) -> int:
	return level - 1


static func constitution_bonus(level: int) -> int:
	return level / CON_EVERY


static func points_earned(level: int) -> int:
	return level / POINT_EVERY


static func speed_bonus(level: int) -> float:
	return SPEED_PER_STEP * (mini(level, SPEED_TOP) / SPEED_EVERY)


## Whether reaching `level` adds Tempo.
static func gives_speed(level: int) -> bool:
	return level % SPEED_EVERY == 0 and level <= SPEED_TOP


## The hero a monster of `level` is a fair fight for: life (level rewards,
## trained Konstitution and worn gear together), power and hardening. At
## level 18 power and hardening are those of Mines.BENCHMARK.
static func expected_life(level: int) -> int:
	return 5 + life_bonus(level) + constitution_bonus(level) + roundi((level - 1) * 10.0 / 17.0)


static func expected_power(level: int) -> int:
	return 1 + roundi((level - 1) * 11.0 / 17.0)


static func expected_hardening(level: int) -> int:
	return roundi((level - 1) * 4.0 / 17.0)


## What a hero of these levels typically wears (the equipment reference):
## the gear behind EXPECTED power and hardening, with about half the level
## points put into Stärke. tests/hero_level.gd checks that they agree.
const GEAR_REFERENCE := {
	1: ["schwert", "lederwams", "lederstiefel"],
	5: ["axt", "rundschild", "kettenhemd", "knochenhelm", "amulett_leben", "eilstiefel"],
	10: ["langschwert", "wappenschild", "kettenhemd", "ritterhelm", "koenigsumhang", "rubinring", "amulett_kraft", "eilstiefel"],
	15: ["rabenklinge", "drachenschild", "plattenpanzer", "ritterhelm", "koenigsumhang", "rubinring", "amulett_kraft", "eilstiefel", "phoenixfeder"],
	20: ["runenhammer", "drachenschild", "plattenpanzer", "ritterhelm", "koenigsumhang", "rubinring", "amulett_kraft", "axtreif", "eilstiefel", "phoenixfeder"],
}


## The reference gear for a hero of `level`: the nearest step at or below it.
static func reference_gear(level: int) -> Array:
	var best := 1
	for step in GEAR_REFERENCE:
		if step <= level and step > best:
			best = step
	return GEAR_REFERENCE[best]


## Puts a hero of `level` into its reference gear (for tests and trials).
static func dress(player: Player, level: int) -> void:
	player.hero_xp = total_for(level)
	player.equipped = {}
	for id in reference_gear(level):
		var slot: String = Items.ALL[id].slot
		player.equipped["spezial_1" if slot == "spezial" else slot] = id
	player.refresh_stats()
	player.hp = player.max_hp


## The share of a hero's life a fight with this monster costs, one on one:
## the time the hero needs to fell it, times what it deals per second.
static func fight_cost(level: int, hp: int, damage: int, hardening: int, cooldown: float) -> float:
	var blows := ceili(float(hp) / Player.soak(expected_power(level), hardening))
	var taken := blows * SWING * Player.soak(damage, expected_hardening(level)) / maxf(cooldown, 0.1)
	return taken / expected_life(level)


## The lowest level for which a monster with these numbers is a fair fight
## (MAX + 1 when not even a level MAX hero would call it fair).
static func monster_level(hp: int, damage: int, hardening: int, cooldown: float) -> int:
	for level in range(1, MAX + 1):
		if fight_cost(level, hp, damage, hardening, cooldown) <= FAIR_SHARE:
			return level
	return MAX + 1


## A monster's level by its kind and numbers.
static func rate(kind: String, hp: int, damage: int, hardening: int, cooldown: float) -> int:
	if FIXED.has(kind):
		return FIXED[kind]
	return mini(monster_level(hp, damage, hardening, cooldown), MAX)


## The hero level the world measures a hero of `hero` by: their own, but no
## more than WORLD_TOP, so the top areas stay worth it above it.
static func measured(hero: int) -> int:
	return mini(hero, WORLD_TOP)


## How much XP shrinks for something `level` that a hero of `hero` does.
static func low_factor(level: int, hero: int) -> float:
	var below := measured(hero) - level - LOW_GAP
	return 1.0 if below <= 0 else maxf(LOW_FLOOR, 1.0 - LOW_STEP * below)


## XP for felling a monster of `level`.
static func kill_xp(level: int, hero: int, boss := false) -> int:
	var xp := KILL_XP * (level + 1) * (BOSS_FACTOR if boss else 1)
	return maxi(1, roundi(xp * low_factor(level, hero)))


## XP for `minutes` of work at a place of `level`.
static func time_xp(minutes: float, level: int, hero: int) -> int:
	return maxi(1, roundi(minutes * KILL_XP * (level + 1) * low_factor(level, hero)))


## XP for a finished task (see TASKS).
static func task_xp(id: String, hero: int) -> int:
	var t: Array = TASKS.get(id, [TASK_MINUTES, VILLAGE_LEVEL])
	return time_xp(t[0], t[1], hero)


## The area a monster of `kind` belongs to on `level` ("" in the dungeon,
## whose floors keep their own numbers).
static func area_of(level: Level, kind: String) -> String:
	if level == null:
		return ""
	if level.outdoor:
		var stats: Dictionary = Enemy.KINDS.get(kind, {})
		if stats.get("mountain", false):
			return "berge"
		if kind in Quests.BANDITS:
			return "pass"
		if stats.get("beast", false) and not stats.get("horror", false):
			return "senke"
		return "loecher" if stats.get("horror", false) else "dorf"
	return BUILDING_AREAS.get(level.building, "")


## The level a monster of natural level `natural` is lifted to in `area`.
static func area_target(area: String, natural: int) -> int:
	if not AREAS.has(area):
		return natural
	var a: Dictionary = AREAS[area]
	var lo: int = a.from[0]
	var hi: int = a.from[1]
	var share := clampf(float(natural - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	return a.min + roundi(share * (a.max - a.min))


## The level of a place, for riddles solved and loot found there: an area's
## lowest level, or a dungeon floor's own (1 on the first floor, 5 on the tenth).
static func place_level(level: Level) -> int:
	if level == null:
		return 1
	if level.outdoor:
		return VILLAGE_LEVEL
	var area: String = BUILDING_AREAS.get(level.building, "")
	if area != "":
		return AREAS[area].min
	if level.building != "":
		return VILLAGE_LEVEL
	return 1 + clampi(level.depth, 0, Enemy.DEEPEST) * 4 / Enemy.DEEPEST


## A rune tablet's place: the mine it stands in.
static func rune_level(theme: String) -> int:
	return AREAS["mine2" if theme == "kristall" else "mine1"].min

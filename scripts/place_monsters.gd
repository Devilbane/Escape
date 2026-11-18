class_name PlaceMonsters
extends RefCounted
## Which monsters live in a place, and at which levels: read from the map file
## itself (the letters that put a monster on a tile, the monsters made in the
## map workshop and, in the open air, what it spawns besides) and rated the
## way the game rates them when they appear (see Enemy.typical_level).
## The compendium's Places page shows the result (Menus._build_places).

## What the open air spawns besides its map letters (see Outdoor): the risen
## dead of the night, the wolf pack and the chief's call.
const OUTDOOR_EXTRA := ["wolf", "halsabschneider"]


## The monsters of the map file `path`, which is the floor numbered `index`:
## {"kinds": [{"kind", "level", "count"}, ...] sorted by level and then name,
## "low", "high"}; no kinds (and low and high 0) in a place without monsters.
static func of(path: String, index: int) -> Dictionary:
	var map := LevelMap.load_file(path)
	var outdoor := map.is_outdoor()
	var building := map.get_header("building")
	var out := {"kinds": [], "low": 0, "high": 0}
	# A village building is a safe room unless it is a lair (see Level).
	if not outdoor and building != "" and not map.has_header("lair"):
		return out
	var letters: Dictionary = Enemy.WILD_LETTERS if outdoor else Enemy.LETTERS
	var made := map.creations()
	var found := {}  # id -> {"kind", "custom", "count"}
	for row in map.grid:
		for ch in row:
			if letters.has(ch):
				_add(found, letters[ch], {}, letters[ch])
			elif made.has(ch) and made[ch].type == "monster":
				_add(found, made[ch].base, Creations.monster_stats(made[ch]), "%s:%s" % [made[ch].base, ch])
	if outdoor and not found.is_empty():
		for kind in Outdoor.NIGHT_DEAD_KINDS + OUTDOOR_EXTRA:
			_add(found, kind, {}, kind, 0)
	var by_kind := {}  # kind -> {"level", "count"}, a kind made twice shows once
	for id in found:
		var f: Dictionary = found[id]
		var level := Enemy.typical_level(f.kind, index, outdoor, building, f.custom)
		if not by_kind.has(f.kind):
			by_kind[f.kind] = {"kind": f.kind, "level": level, "count": 0}
		by_kind[f.kind].level = maxi(by_kind[f.kind].level, level)
		by_kind[f.kind].count += f.count
	for kind in by_kind:
		out.kinds.append(by_kind[kind])
	out.kinds.sort_custom(func(a, b): return a.level < b.level or (a.level == b.level and a.kind < b.kind))
	# The guardian's fixed level is no measure of the place's monsters: it only
	# counts when nobody else lives there.
	var measure: Array = out.kinds.filter(func(k): return k.kind != "waechter")
	if measure.is_empty():
		measure = out.kinds
	if not measure.is_empty():
		out.low = measure[0].level
		out.high = measure[measure.size() - 1].level
	return out


static func _add(found: Dictionary, kind: String, custom: Dictionary, id: String, count := 1) -> void:
	if not Enemy.KINDS.has(kind):
		return
	if not found.has(id):
		found[id] = {"kind": kind, "custom": custom, "count": 0}
	found[id].count += count


## "Monster level 5" or "Monster levels 3 to 7", in the player's language.
static func range_text(low: int, high: int) -> String:
	if low == high:
		return Lang.t("Monsterstufe %d") % low
	return Lang.t("Monsterstufen %d bis %d") % [low, high]


## "Skelettkrieger (Stufe 3), Skelettschütze (Stufe 4)": who lives there.
static func list_text(kinds: Array) -> String:
	var parts := []
	for k in kinds:
		parts.append(Lang.t("%s (Stufe %d)") % [Lang.t(MonsterLore.monster_name(k.kind)), k.level])
	return ", ".join(parts)

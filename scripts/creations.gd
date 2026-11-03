class_name Creations
extends RefCounted
## Your own monsters, people and gear, made in the map workshop (see
## LevelEditor) and kept in the map file itself, so one file is the whole map.
##
## Each creation takes one of the digits in LETTERS and is written as a
## header line of its map:
##
##   custom: 1 {"type": "monster", "base": "krieger", "name": "Knochenfürst", "hp": 8}
##   custom: 2 {"type": "npc", "name": "Bruder Anselm", "model": "Mage", "lines": ["..."]}
##   custom: 3 {"type": "item", "id": "eigen_knochenkrone", "base": "knochenhelm", "name": "Knochenkrone", "power": 2}
##
## Wherever its digit stands on the map, the level places it: a monster that
## fights like its "base" kind with the numbers given (see Enemy.custom), a
## person who stands there and says their lines when the hero runs into them
## (see DungeonNpc), or a piece of gear lying on the floor, which looks like
## its "base" item and wears like it with the values given.
##
## Gear made here joins Items.ALL when a map that holds it is read (and at the
## start of the game, see register_all), so a saved game that carries it
## still knows it. It is never sold, found as loot or forged.

const HEADER := "custom:"
## The map letters a creation can take (see Tiles.DUNGEON).
const LETTERS := "1234567890"
const TYPES := ["monster", "npc", "item"]
## Where the workshop keeps the maps made with it.
const USER_DIR := "user://karten/"

## The monsters a creation can be based on: every kind in the game that
## fights, the bosses too. [family name, kinds]: the workshop lists them by
## family (see EditorCreations). A boss keeps the fight of its own (the
## dragon's fire breath, the bandit chief's charge, the Mountain King's rage)
## and shows its health bar at the top; it takes the creation's name there.
const MONSTER_FAMILIES := [
	["Untote", ["krieger", "schuetze", "magier", "wicht", "koloss", "waechter", "fog_wraith"]],
	["Räuber", ["halsabschneider", "wilderer", "schlaeger", "klippenschuetze", "hauptmann"]],
	["Tiere der Wildnis", ["wolf", "ork", "yeti", "spinne"]],
	["Drachenhöhle", ["fledermaus", "schleim", "drache"]],
	["Berge und Minen", ["eiswolf", "bergork", "felstroll", "kristallschleim", "glutschleim", "bergkoenig"]],
	["Grauen", ["hohle_mutter", "bleicher_waechter", "schlund"]],
]
## Every base, in the order of MONSTER_FAMILIES (tests/level_editor.gd checks
## that the two agree and that every kind that fights is here).
const MONSTER_BASES := ["krieger", "schuetze", "magier", "wicht", "koloss", "waechter", "fog_wraith",
		"halsabschneider", "wilderer", "schlaeger", "klippenschuetze", "hauptmann",
		"wolf", "ork", "yeti", "spinne",
		"fledermaus", "schleim", "drache",
		"eiswolf", "bergork", "felstroll", "kristallschleim", "glutschleim", "bergkoenig",
		"hohle_mutter", "bleicher_waechter", "schlund"]
## The bosses among them: each fights with a script of its own (see
## Level._spawn_enemy).
const MONSTER_BOSSES := ["hauptmann", "drache", "bergkoenig"]
## What each base is called in the workshop (German, see Lang).
const MONSTER_NAMES := {
	"krieger": "Skelettkrieger", "schuetze": "Skelettschütze", "magier": "Skelettmagier",
	"wicht": "Skelettwicht", "koloss": "Skelettkoloss", "waechter": "Wächter in Rüstung",
	"fog_wraith": "Nebelgeist",
	"halsabschneider": "Halsabschneider", "wilderer": "Wilderer", "schlaeger": "Schläger",
	"klippenschuetze": "Klippenschütze", "hauptmann": "Räuberhauptmann",
	"wolf": "Wolf", "ork": "Ork", "yeti": "Yeti", "spinne": "Spinne",
	"fledermaus": "Fledermaus", "schleim": "Schleim", "drache": "Drache",
	"eiswolf": "Eiswolf", "bergork": "Bergork", "felstroll": "Felstroll",
	"kristallschleim": "Kristallschleim", "glutschleim": "Glutschleim", "bergkoenig": "Bergkönig",
	"hohle_mutter": "Die Hohle Mutter", "bleicher_waechter": "Der Bleiche Wächter", "schlund": "Der Schlund",
}
## The numbers of a monster: [key, label, lowest, highest, step]. A key left
## out keeps the base's own value.
const MONSTER_STATS := [
	["hp", "Leben", 1, 200, 1],
	["damage", "Schaden", 1, 10, 1],
	["armor", "Härte", 0, 4, 1],
	["speed", "Tempo", 1.0, 9.0, 0.2],
	["cooldown", "Sekunden je Schlag", 0.6, 4.0, 0.1],
	["size", "Größe", 0.6, 2.0, 0.05],
	["gold", "Gold beim Sieg", 0, 100, 1],
]

## The people: their body, the parts they may show (hats, capes, what they
## hold) and what they may be doing.
const NPC_MODELS := ["Rogue", "Knight", "Barbarian", "Mage"]
const NPC_MODEL_NAMES := {"Rogue": "Schurke", "Knight": "Ritter", "Barbarian": "Barbar", "Mage": "Magier"}
const NPC_PARTS := {
	"Rogue": ["Rogue_Cape", "Knife", "1H_Crossbow"],
	"Knight": ["Knight_Helmet", "Knight_Cape", "1H_Sword", "Round_Shield", "Badge_Shield"],
	"Barbarian": ["Barbarian_Hat", "Barbarian_Cape", "1H_Axe", "2H_Axe", "Mug"],
	"Mage": ["Mage_Hat", "Mage_Cape", "2H_Staff", "Spellbook_open"],
}
const PART_NAMES := {
	"Rogue_Cape": "Umhang", "Knife": "Messer", "1H_Crossbow": "Armbrust",
	"Knight_Helmet": "Helm", "Knight_Cape": "Umhang", "1H_Sword": "Schwert", "Round_Shield": "Rundschild", "Badge_Shield": "Wappenschild",
	"Barbarian_Hat": "Fellmütze", "Barbarian_Cape": "Umhang", "1H_Axe": "Axt", "2H_Axe": "Große Axt", "Mug": "Krug",
	"Mage_Hat": "Hut", "Mage_Cape": "Umhang", "2H_Staff": "Stab", "Spellbook_open": "Buch",
}
## [animation, label]: what the person does on their spot.
const NPC_POSES := [["Idle", "Steht"], ["Sit_Floor_Idle", "Sitzt"], ["Interact", "Hantiert"],
		["Spellcast_Raise", "Zaubert"], ["Cheer", "Jubelt"], ["Lie_Idle", "Liegt"]]
const NPC_MAX_LINES := 6

## The slots gear can be made for: everything worn (no books, crates or
## things for tasks).
const ITEM_SLOTS := ["waffe", "schild", "kopf", "umhang", "ruestung", "schuhe", "amulett", "ring", "armreif", "rucksack"]
## The values of a piece of gear: [key, label, lowest, highest, step].
## "speed" and "block" are shares (0.1 = 10 %).
const ITEM_STATS := [
	["power", "Kraft", 0, 6, 1],
	["hp", "Leben", 0, 8, 1],
	["armor", "Härte", 0, 4, 1],
	["speed", "Tempo", 0.0, 0.3, 0.01],
	["block", "Blocken", 0.0, 0.5, 0.01],
	["weight", "Gewicht (kg)", 0.0, 10.0, 0.1],
	["price", "Preis", 1, 200, 1],
]
## Slots whose worn piece colours the hero ("tint", see GearLook).
const TINTED_SLOTS := ["umhang", "ruestung", "schuhe"]


## A new creation of a type, with sensible first values.
static func blank(type: String) -> Dictionary:
	match type:
		"monster":
			return {"type": "monster", "base": "krieger", "name": "Eigenes Monster"}
		"npc":
			return {"type": "npc", "name": "Fremder", "model": "Rogue", "sex": "male", "show": [],
					"colors": ["#7a6a8c", "#594d40", "#8c7340"], "pose": "Idle", "lines": ["Sei gegrüßt, Wanderer."]}
		_:
			return {"type": "item", "id": "", "base": "schwert", "name": "Eigenes Schwert"}


## The line of a map file for a creation on a letter.
static func to_line(letter: String, spec: Dictionary) -> String:
	return "%s %s %s" % [HEADER, letter, JSON.stringify(spec, "", false)]


## Reads a "custom:" line: {"letter", "spec"}, or {} if it does not make sense.
static func parse_line(line: String) -> Dictionary:
	var rest := line.substr(HEADER.length()).strip_edges()
	var space := rest.find(" ")
	if space != 1 or not LETTERS.contains(rest[0]):
		return {}
	var data = JSON.parse_string(rest.substr(space + 1))
	if not data is Dictionary or not data.get("type", "") in TYPES:
		return {}
	return {"letter": rest[0], "spec": checked(data)}


## A creation with every value inside its bounds and its id filled in, so a
## map written by hand cannot break the game.
static func checked(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate(true)
	out.name = str(out.get("name", "")).strip_edges().left(40)
	match out.type:
		"monster":
			if not out.get("base", "") in MONSTER_BASES:
				out.base = "krieger"
			for s in MONSTER_STATS:
				if out.has(s[0]):
					out[s[0]] = _bounded(out[s[0]], s)
		"npc":
			if not out.get("model", "") in NPC_MODELS:
				out.model = "Rogue"
			out.sex = "female" if out.get("sex", "") == "female" and out.model == "Rogue" else "male"
			var parts: Array = NPC_PARTS[out.model]
			out.show = Array(out.get("show", [])).filter(func(p): return p in parts)
			var colors: Array = out.get("colors", [])
			while colors.size() < 3:
				colors.append("#ffffff")
			out.colors = colors.slice(0, 3).map(func(c): return str(c) if Color.html_is_valid(str(c)) else "#ffffff")
			if not NPC_POSES.any(func(p): return p[0] == out.get("pose", "")):
				out.pose = "Idle"
			out.lines = Array(out.get("lines", [])).map(func(l): return str(l).strip_edges()).filter(func(l): return l != "").slice(0, NPC_MAX_LINES)
		"item":
			var base: String = out.get("base", "")
			if not Items.ALL.has(base) or Items.ALL[base].get("custom", false) or not Items.ALL[base].slot in ITEM_SLOTS:
				out.base = "schwert"
			for s in ITEM_STATS:
				if out.has(s[0]):
					out[s[0]] = _bounded(out[s[0]], s)
			if str(out.get("id", "")) == "":
				out.id = item_id(out.name)
	if out.has("tint") and not Color.html_is_valid(str(out.tint)):
		out.erase("tint")
	return out


static func _bounded(value, stat: Array):
	var v := clampf(float(value), float(stat[2]), float(stat[3]))
	return roundi(v) if stat[4] is int else snappedf(v, float(stat[4]))


## The id of gear made here, from its name: "eigen_" and the name in plain
## lower-case letters, so the same name always gives the same id.
static func item_id(item_name: String) -> String:
	var plain := item_name.to_lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
	var out := ""
	for ch in plain:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_"):
			out += "_"
	return "eigen_" + out.strip_edges().trim_suffix("_").trim_prefix("_")


## What a creation is called in the workshop: its own name, or what it is.
static func label_of(spec: Dictionary) -> String:
	if str(spec.get("name", "")) != "":
		return spec.name
	match spec.type:
		"monster":
			return Lang.t(MONSTER_NAMES.get(spec.base, spec.base))
		"npc":
			return Lang.t("Person")
	return Lang.t("Ausrüstung")


# --- Gear -------------------------------------------------------------------

## The item a creation of type "item" stands for: its base item with the
## values given, kept apart from loot and every shop.
static func item_of(spec: Dictionary) -> Dictionary:
	var item: Dictionary = Items.ALL[spec.base].duplicate(true)
	item.name = spec.name if spec.name != "" else item.name
	for s in ITEM_STATS:
		if spec.has(s[0]):
			item[s[0]] = spec[s[0]]
	if spec.has("tint") and item.slot in TINTED_SLOTS:
		item.tint = Color.html(spec.tint)
	if item.has("block") and not item.has("durability"):
		item.durability = 5
	for k in ["unique", "smith", "wanderer", "crafted", "effect"]:
		item.erase(k)
	item.no_loot = true
	item.custom = true
	return item


## Adds the gear of a creation to Items.ALL (again, if it changed).
static func register(spec: Dictionary) -> void:
	if spec.get("type", "") == "item" and str(spec.get("id", "")).begins_with("eigen_"):
		Items.ALL[spec.id] = item_of(spec)


## Every creation in a map file: letter -> spec.
static func read_file(path: String) -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with(HEADER):
			var c := parse_line(line.strip_edges())
			if not c.is_empty():
				out[c.letter] = c.spec
	return out


## Learns the gear of every map there is, the game's own and the ones made in
## the workshop, so saved games that carry such a piece still know it.
static func register_all() -> void:
	for dir in ["res://levels/", USER_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".txt"):
				for spec in read_file(dir + f).values():
					register(spec)


# --- Monsters ---------------------------------------------------------------

## The numbers a monster creation changes in its base kind (see Enemy.custom).
static func monster_stats(spec: Dictionary) -> Dictionary:
	var out := {}
	for s in MONSTER_STATS:
		if spec.has(s[0]) and s[0] != "gold":
			out[s[0]] = spec[s[0]]
	if spec.has("gold"):
		out.purse = [int(spec.gold) / 2, int(spec.gold)]
	if spec.has("tint"):
		out.tint = Color.html(spec.tint)
	if spec.has("roam"):
		out.roam = bool(spec.roam)
	if str(spec.get("name", "")) != "":
		out.title = spec.name
	return out


# --- People -----------------------------------------------------------------

## A creation of type "npc" in the shape Villager.dress_model reads.
static func npc_look(spec: Dictionary) -> Dictionary:
	return {"model": spec.model, "show": spec.show, "sex": spec.sex,
			"colors": spec.colors.map(func(c): return Color.html(c))}

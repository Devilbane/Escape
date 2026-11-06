class_name TreasureMaps
extends RefCounted
## Treasure maps from messages in a bottle (see Fishing): now and then a
## bottle fished up holds an old map instead of a note. Each map is found
## once only and leads to a place in the open air:
##
##   "dorf"    a chest buried in the village, at the tile "?" of the
##             outdoor map. Reading the map marks the spot with a cross of
##             stones on fresh earth: run into it (or click it) to dig the
##             chest up, and it opens right away.
##   "grotte"  a hidden cave in the western woods, under a boulder at the
##             tile ">". Once the map is read, run into the boulder to roll
##             it aside: a hole opens beneath it, down into the floor with
##             the line "building: grotte" (a small cave of bats, slimes and
##             a spider, with a chest at the back).
##
## Until a spot is done it carries a red cross on the hero's map in the
## journal (see MapView), and the map's text goes into the compendium so it
## can be read again. Before a map is found, the spot is plain grass and the
## boulder is just a boulder.
##
## The fishing side only asks pick() which map a bottle holds and reports it
## on the event bus (treasure_map_found); read() listens there.

## What became of a map (state, saved as "treasure_maps"). No entry: not
## found yet.
const READ := "gelesen"
## The village chest is dug up but not opened yet (the bag was full).
const DUG := "ausgegraben"
## The boulder over the hidden cave is rolled aside.
const OPEN := "offen"
## The village chest is opened.
const DONE := "geborgen"

## The maps: the map letter of their spot, the title, a short line where to
## look (for the message) and the whole map as it reads (for the compendium).
const MAPS := {
	"dorf": {
		"letter": "?",
		"title": "Die Karte vom Mühlenkreuz",
		"where": "Ein rotes Kreuz, zwei Schritte südlich der Windmühle im Dorf.",
		"lore": "Die Karte vom Mühlenkreuz: Eine verblichene Skizze des Dorfes, aus einer Flaschenpost. Gleich südlich der Windmühle ist ein rotes Kreuz gemalt, und darunter steht: „Hier liegt meine Truhe. Wer gräbt, der findet.“",
	},
	"grotte": {
		"letter": ">",
		"title": "Die Karte vom Findling",
		"where": "Ein Findling am Westrand des Waldes, wo der Pfad vom Friedhof nach Osten biegt.",
		"lore": "Die Karte vom Findling: Der Westwald, aus einer Flaschenpost. Wo der Pfad vom Friedhof nach Osten biegt, ist am Waldrand ein großer Stein gezeichnet und darunter eine Höhle. Daneben steht: „Den Stein beiseite, dann hinab. Die Fledermäuse beißen nur ein bisschen.“",
	},
}
## The order the maps turn up in when both are still to be found is random.
## The chance that a bottle holds a map while one is still out there.
const MAP_CHANCE := 0.35

## Station kinds: the marked spot of the village chest, and the boulder over
## the hidden cave.
const DIG := "schatzstelle"
const BOULDER := "findling"
## The floor under the boulder ("building: grotte").
const CAVE := "grotte"
const CAVE_NAME := "die verborgene Grotte"
## What the village chest holds: copper and a piece of gear of at least this
## tier, as good as the village's best.
const CHEST_GOLD := 40
const CHEST_TIER := "selten"
## How long digging takes (seconds) before the chest comes up, and how long
## the boulder takes to roll aside.
const DIG_TIME := 1.4
const ROLL_TIME := 1.1
## Where the boulder rests once rolled aside, from the middle of its tile:
## towards the forest on its west side.
const ROLLED := Vector3(-3.1, 0, 0.9)
const BOULDER_SCALE := 8.5
const EARTH := Color(0.32, 0.22, 0.14)
const MAP_RED := Color(0.85, 0.2, 0.15)

var game: Node
## Map id -> state (see READ, DUG, OPEN, DONE).
var state := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	state.clear()


## The maps still out there, in a fixed order.
func left() -> Array:
	var out := []
	for id in MAPS:
		if not state.has(id):
			out.append(id)
	return out


## Which map a bottle holds: "" for none (a note and coins, as before).
func pick(rng: RandomNumberGenerator) -> String:
	var out := left()
	if out.is_empty() or rng.randf() >= MAP_CHANCE:
		return ""
	return out[rng.randi() % out.size()]


## Whether the spot of a map carries a cross on the hero's map: found, and
## not done yet (the village chest until it is opened, the cave until the
## boulder is rolled aside; then its hole is plain to see).
func marked(id: String) -> bool:
	return state.get(id, "") in [READ, DUG]


## The hero found a map in a bottle (see Fishing.take): its spot shows in
## the world and on the hero's map, and its text goes into the compendium.
func read(id: String) -> void:
	if not MAPS.has(id) or state.has(id):
		return
	state[id] = READ
	var map: Dictionary = MAPS[id]
	Events.teach(map.lore)
	if game == null:
		return
	game.journal.write("Schatzkarte gefunden: %s", [map.title], game.journal.current_file())
	if game.level is Outdoor:
		build(game.level, id)


## The hero ran into a station of a treasure: digs or rolls.
func use(s: Dictionary) -> void:
	if s.kind == DIG:
		dig(s)
	elif s.kind == BOULDER:
		roll_aside(s)


## Digs up the village chest: a moment of digging with earth flying, then
## the chest comes up and opens (see Game._search).
func dig(s: Dictionary) -> void:
	var lvl: Outdoor = game.level
	s.used = true
	game.player.path.clear()
	game.player.face(s.pos - game.player.global_position)
	game.player.play_once("Interact", DIG_TIME)
	Sfx.play(game, "rummage")
	var earth := Effects.make_spray(EARTH)
	earth.one_shot = true
	earth.position = s.pos + Vector3(0, 0.2, 0)
	lvl.add_child(earth)
	earth.emitting = true
	game.get_tree().create_timer(DIG_TIME).timeout.connect(func():
		if is_instance_valid(earth):
			earth.queue_free()
		if not is_instance_valid(lvl) or game.level != lvl:
			return
		state[s.treasure] = DUG
		Sfx.play(game, "chop", -4.0)
		var chest := build(lvl, s.treasure)
		Events.tell(Lang.t("Du gräbst eine alte Truhe aus!"), game.GOLD)
		if not chest.is_empty():
			game._search(chest))


## Rolls the boulder off the hidden cave: it rumbles aside towards the
## forest, and a hole into the dark opens where it lay.
func roll_aside(s: Dictionary) -> void:
	var lvl: Outdoor = game.level
	s.used = true
	game.player.path.clear()
	game.player.face(s.pos - game.player.global_position)
	game.player.play_once("Interact", 0.6)
	Sfx.play(game, "rumble")
	state[s.treasure] = OPEN
	var boulder = lvl.treasure_parts.get(s.treasure + ":stein")
	if not is_instance_valid(boulder):
		build(lvl, s.treasure)
		return
	var tween: Tween = boulder.create_tween().set_parallel()
	tween.tween_property(boulder, "position", s.pos + ROLLED, ROLL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(boulder, "rotation:z", boulder.rotation.z + 1.6, ROLL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		if not is_instance_valid(lvl):
			return
		_open_cave(lvl, s.cell)
		Events.tell(Lang.t("Der Findling rollt beiseite. Darunter führt ein Loch in die Tiefe!"), game.GOLD)
		game.journal.write("Verborgene Grotte gefunden", [], game.journal.current_file()))


## The village chest was opened (see Game._search): the treasure is found.
func opened(obj: Dictionary) -> void:
	var id: String = obj.get("treasure", "")
	if id == "" or state.get(id, "") == DONE:
		return
	state[id] = DONE
	game.journal.write("Schatz gehoben: %s", [MAPS[id].title], game.journal.current_file())


# --- In the world -----------------------------------------------------------

## Remembers the tile of a map's spot while the outdoor map is built (see
## Outdoor._build_outdoor_cell) and builds what shows there now.
static func place(lvl: Outdoor, c: Vector2i, letter: String) -> void:
	for id in MAPS:
		if MAPS[id].letter == letter:
			lvl.treasure_cells[id] = c
			if id == CAVE:
				# Boulder or hole, the tile is never walked on.
				lvl._add_solid(lvl.cell_to_world(c), Vector3(2.8, 1.6, 2.8))
			build(lvl, id)


## Builds (again) what shows at a map's spot in its present state, and the
## station there. Returns the village chest when it is built.
static func build(lvl: Outdoor, id: String) -> Dictionary:
	if not lvl.treasure_cells.has(id):
		return {}
	var c: Vector2i = lvl.treasure_cells[id]
	var at: String = lvl.treasure.get(id, "")
	_clear(lvl, id)
	if id == CAVE:
		_build_boulder(lvl, c, at)
		return {}
	if lvl.astar.is_in_boundsv(c):
		lvl.astar.set_point_solid(c, blocks(lvl, id))
	if at == READ:
		_build_cross(lvl, c, id)
	elif at == DUG:
		return _build_chest(lvl, c, id)
	return {}


## Whether the spot of a map stands in the way (see Outdoor._setup_astar):
## the marked village spot and its dug-up chest do; the boulder's tile is
## never walkable anyway.
static func blocks(lvl: Outdoor, id: String) -> bool:
	return id != CAVE and lvl.treasure.get(id, "") in [READ, DUG]


static func _clear(lvl: Outdoor, id: String) -> void:
	for key in lvl.treasure_parts.keys():
		if str(key).begins_with(id + ":"):
			var node = lvl.treasure_parts[key]
			if is_instance_valid(node):
				node.queue_free()
			lvl.treasure_parts.erase(key)
	for s in lvl.stations.duplicate():
		if s.get("treasure", "") == id:
			lvl.stations.erase(s)


## The marked spot: a patch of fresh, dark earth with a cross of small,
## pale stones laid on it, and a faint glint over it.
static func _build_cross(lvl: Outdoor, c: Vector2i, id: String) -> void:
	var pos := lvl.cell_to_world(c)
	var holder := Node3D.new()
	holder.name = "Schatzstelle"
	lvl.add_child(holder)
	lvl.treasure_parts[id + ":kreuz"] = holder
	var mound := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 0.5
	dome.radial_segments = 16
	dome.rings = 6
	mound.mesh = dome
	var soil := StandardMaterial3D.new()
	soil.albedo_color = EARTH
	soil.roughness = 1.0
	mound.material_override = soil
	mound.position = pos + Vector3(0, -0.08, 0)
	mound.scale = Vector3(1.2, 1.0, 1.0)
	holder.add_child(mound)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.78, 0.76, 0.7)
	stone_mat.roughness = 0.9
	for arm in [0.785, -0.785]:
		for i in range(-2, 3):
			var stone := MeshInstance3D.new()
			var pebble := SphereMesh.new()
			pebble.radius = 0.13
			pebble.height = 0.16
			pebble.radial_segments = 8
			pebble.rings = 4
			stone.mesh = pebble
			stone.material_override = stone_mat
			stone.position = pos + Vector3(cos(arm), 0, sin(arm)) * i * 0.32 + Vector3(0, 0.16, 0)
			holder.add_child(stone)
	var glint := Effects.make_sparkles(Color(1.0, 0.85, 0.45))
	glint.amount = 6
	glint.position = pos + Vector3(0, 0.4, 0)
	holder.add_child(glint)
	# Low, so the hero runs into it rather than over it.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.4, 1.6)
	shape.shape = box
	shape.position = pos + Vector3(0, 0.7, 0)
	body.add_child(shape)
	holder.add_child(body)
	lvl.stations.append({"kind": DIG, "treasure": id, "cell": c, "pos": pos, "used": false})


## The village chest, dug up: an open pit of earth round it, and the chest
## itself (a treasure chest, see Level._build_chest) with what the map
## promised in it.
static func _build_chest(lvl: Outdoor, c: Vector2i, id: String) -> Dictionary:
	var pos := lvl.cell_to_world(c)
	var holder := Node3D.new()
	holder.name = "Schatzgrube"
	lvl.add_child(holder)
	lvl.treasure_parts[id + ":grube"] = holder
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.6
	disc.height = 0.06
	disc.radial_segments = 16
	ring.mesh = disc
	var soil := StandardMaterial3D.new()
	soil.albedo_color = EARTH
	soil.roughness = 1.0
	ring.material_override = soil
	ring.position = pos + Vector3(0, 0.02, 0)
	holder.add_child(ring)
	lvl._build_chest(c)
	var obj: Dictionary = lvl.interactables[-1]
	lvl.clear_loot(obj)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:treasure:%s" % [lvl.level_name, id])
	obj.loot = {"gold": CHEST_GOLD, "item": lvl.loot_item(rng, Level.tier_rank(CHEST_TIER), HeroLevel.AREAS.dorf.max)}
	obj.treasure = id
	return obj


## The boulder over the hidden cave: before the map is read and while it is
## marked, it sits on the hole (a station once the map is read); once rolled
## aside it rests at the forest's edge, and the hole is open.
static func _build_boulder(lvl: Outdoor, c: Vector2i, at: String) -> void:
	var pos := lvl.cell_to_world(c)
	var holder := Node3D.new()
	holder.name = "Findling"
	lvl.add_child(holder)
	lvl.treasure_parts[CAVE + ":stein"] = holder
	var rolled := at == OPEN or at == DONE
	holder.position = pos + (ROLLED if rolled else Vector3.ZERO)
	if rolled:
		holder.rotation.z = 1.6
	lvl._put("rock_single_A", Vector3.ZERO, 0.4, BOULDER_SCALE, holder)
	if rolled:
		_open_cave(lvl, c)
	elif at == READ:
		lvl.stations.append({"kind": BOULDER, "treasure": CAVE, "cell": c, "pos": pos, "reach": 2.6, "used": false})


## The hole under the boulder: the same dark pit as the creepy holes in the
## ground (see Outdoor._build_hole), and the way down into the cave.
static func _open_cave(lvl: Outdoor, c: Vector2i) -> void:
	var pos := lvl.cell_to_world(c)
	var holder := Node3D.new()
	holder.name = "Grotteneingang"
	lvl.add_child(holder)
	lvl.treasure_parts[CAVE + ":loch"] = holder
	VillageProps.build_hole_rim(holder, pos, 1.3)
	var pit := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.32
	disc.bottom_radius = 1.32
	disc.height = 0.02
	disc.radial_segments = 18
	pit.mesh = disc
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	pit.material_override = black
	pit.position = pos + Vector3(0, 0.03, 0)
	holder.add_child(pit)
	var mist := Effects.make_sparkles(Color(0.45, 0.5, 0.62, 0.5))
	mist.position = pos + Vector3(0, 0.4, 0)
	holder.add_child(mist)
	for s in lvl.stations.duplicate():
		if s.get("treasure", "") == CAVE:
			lvl.stations.erase(s)
	lvl.doors[CAVE] = pos + Vector3(Level.TILE * 0.8, 0, 0)
	if lvl.interiors.has(CAVE):
		lvl.stations.append({"kind": "eingang", "building": CAVE, "name": CAVE_NAME, "treasure": CAVE,
				"cell": c, "pos": pos, "reach": 2.6, "used": false})


## The cells of a map's spot on a map's rows (for the journal's map): every
## tile with its letter.
static func cells_on(rows: Array, id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var letter: String = MAPS[id].letter
	for y in rows.size():
		var row := str(rows[y])
		var x := row.find(letter)
		while x >= 0:
			out.append(Vector2i(x, y))
			x = row.find(letter, x + 1)
	return out


# --- Saved game -------------------------------------------------------------

func for_save() -> Dictionary:
	return state.duplicate()


func load_from(data) -> void:
	state.clear()
	if data is Dictionary:
		for id in data:
			if MAPS.has(str(id)) and str(data[id]) in [READ, DUG, OPEN, DONE]:
				state[str(id)] = str(data[id])

class_name Level
extends Node3D
## Builds a dungeon level from a text map and runs its traps and pickups.
##
## Map legend (one character per 4x4 m tile):
##   #  wall          .  floor           ,  dirt floor
##   P  player start  E  exit stairs     K  key
##   D  locked door   S  spike trap      c  coin
##   C  treasure chest  k  small trunk
##   b  barrel        x  crates          o  pillar        t  table
##   M  skeleton warrior (melee)          A  skeleton archer (ranged)
##   Z  skeleton mage (magic orbs)        w  skeleton minion (small, quick)
##   G  skeleton brute (big, slow, hits hard)
##   H  shrine: grants one gift (more life, strength or speed)
##   B  bed (save and log out)  L  storage chest  V  merchant
##   F  fountain: refills life and cures poison and curses
##   ?  secret wall: looks like a wall until its lever torch is found
##   =  iron bars           U  a vault behind the bars (the bank's cellar)
##   _  pressure plate      Q  an old, heavy stone block (see StoneBlock.heavy)
##   |  iron gate that sinks into the floor for good once a stone block lies
##      on every pressure plate of the level (a block-pushing puzzle room)
##   v  bat   s  slime   R  dragon (spits fire from afar): the monsters of
##      the dragon's lair (see Enemy)
##   y  stone horse statue (the dragon's lair)
##
## The line "secret: normal|uncommon|rare|epic|godborn" sets how rich the
## secret room is (the German ids ungewoehnlich, selten, episch, gottgeboren
## work too). The richer it is, the harder its lever is to
## notice. Any torch near the secret wall can be the lever, a new one each run.
##
## A level with the line "safe: yes" is a safe room without enemies.
## A level with the line "outdoor: yes" lies in the open air and is built by
## Outdoor, with its own map legend. The lines "building: b" and
## "floor: cellar" (or "upstairs") make a level a floor inside the village
## building with that letter: entered by its door, left by its stairs.
## A level with the line "elite: yes" has stronger skeletons with dark bones
## and glowing red eyes.
## A building floor with the line "lair: yes" is no safe room but a dungeon
## of its own beneath the wild (the dragon's lair): its monsters stand
## ready again every time the hero comes down, they carry gold, and the
## halls are dressed with cobwebs, skulls, banners and heaps of coins from
## Quaternius' Modular Dungeon kit.
##
## Barrels, crates, tables, trunks, chests and wall shelves can be searched.

signal key_collected
signal coins_collected(amount: int)
signal door_opened
signal door_locked
signal player_hurt
signal enemy_killed(enemy: Enemy)
signal exit_reached
signal item_collected(id: String)
signal bag_full
signal secret_found(lever_pos: Vector3, wall_pos: Vector3)
## How many of the level's pressure plates have a block on them changed.
signal plates_changed(pressed: int, total: int)
## Every pressure plate is pressed: the iron gate at `pos` opens.
signal gate_opened(pos: Vector3)

const TILE := 4.0
const ASSET_DIR := "res://assets/dungeon/"
const KIT_DIR := "res://assets/kit/"
## Floors, walls, pillars and furniture from Omie's 3D Modular Dungeon Kit
## (CC0): carved stone and wood instead of the flat cartoon pieces. The kit is
## built on a 3 m grid with pieces anchored at a corner, so each part gets
## shifted, scaled and turned onto ours. Wall ends overlap their neighbours a
## little, so every other wall sits 2 cm higher to keep the tops from flickering.
## piece: list of parts [kit model, texture set, offset, scale, turn]
const WALL_PART := ["SM_Wall", "walls", Vector3(2, 0, 0), Vector3(4.0 / 3.0, 4.0 / 2.56, 4.0 / 3.0), 0.0]
const KIT_PIECES := {
	"floor_tile_large": [["SM_TileFloor", "floor", Vector3(2, 0, 2), Vector3(4.0 / 3.0, 1.0, 4.0 / 3.0), 0.0]],
	"floor_dirt_large": [["SM_RockyFloor", "floor", Vector3(2, 0, 2), Vector3(4.0 / 3.0, 1.0, 4.0 / 3.0), 0.0]],
	"wall": [WALL_PART],
	"wall_cracked": [WALL_PART],
	# A tall bookcase stands against a plain wall.
	"wall_shelves": [WALL_PART, ["SM_FullBookShelf", "props", Vector3(0, 0, 1.05), Vector3.ONE * 2.2, PI]],
	# A touch taller than the walls, so the tops do not flicker against each other.
	"pillar": [["SM_Pillar", "floor", Vector3.ZERO, Vector3(2.2, 4.1 / 2.59, 2.2), 0.0]],
	"pillar_decorated": [["SM_Pillar", "floor", Vector3.ZERO, Vector3(2.8, 4.1 / 2.59, 2.8), 0.0]],
	"barrel_large": [["SM_WoodenBarrel", "props", Vector3.ZERO, Vector3.ONE * 2.2, 0.0]],
	"barrel_small": [["SM_WoodenBarrel", "props", Vector3.ZERO, Vector3.ONE * 1.2, 0.0]],
	"crates_stacked": [
		["SM_WoodenCrate", "props", Vector3(-0.2, 0, 0), Vector3.ONE * 2.2, 0.0],
		["SM_MetalCrate", "props", Vector3(0.1, 1.62, 0.1), Vector3.ONE * 1.5, 0.4],
	],
	"trunk_large_A": [["SM_UnlockedChestBronze", "chests", Vector3.ZERO, Vector3.ONE * 2.0, 0.0]],
	"table_medium_decorated_A": [
		["SM_WoodenTable", "props", Vector3.ZERO, Vector3.ONE * 1.6, 0.0],
		["SM_Candle", "props", Vector3(-1.1, 1.0, 0.2), Vector3.ONE * 1.6, 0.0],
		["SM_BookPile", "props", Vector3(0.6, 1.0, -0.2), Vector3.ONE * 1.6, 0.6],
		["SM_Bottle", "props", Vector3(-0.3, 1.0, -0.4), Vector3.ONE * 1.6, 0.0],
	],
	"torch_mounted": [["SM_WallTorch", "wallprops", Vector3(0, 0.2, 0), Vector3.ONE * 2.0, PI]],
}
## Wall decorations for some plain walls: banners and a sword with a shield.
const WALL_DECOR := [
	["SM_RedFlag", "wallprops", Vector3(0, 3.7, 0.55), Vector3.ONE * 2.2, PI],
	["SM_BlueFlag", "wallprops", Vector3(0, 3.7, 0.55), Vector3.ONE * 2.2, PI],
	["SM_SwordAndShield", "wallprops", Vector3(0, 2.4, 0.55), Vector3.ONE * 1.8, PI],
]
## The bright cartoon stone of the pieces the kit has no match for is darkened
## to sit among the kit's stone.
const STONE_TINT := Color(0.6, 0.56, 0.52)
## Colour of the iron spikes in spike traps.
const SPIKE_IRON := Color(0.5, 0.5, 0.53)
## The grey of the kit's floor tiles, for spike and grate tiles.
const FLOOR_GREY := Color(0.74, 0.73, 0.71)
const TINTED_PIECES := ["floor_tile_big_grate", "floor_tile_big_spikes", "wall_archedwindow_gated", "wall_doorway", "wall_doorway_door", "stairs"]
const SOLID := "#bxotkCDHBLVF?f=U|"
## Reach for searching: anything on a neighbouring tile.
const SEARCH_RANGE := 4.3
## Height of walls between the camera and the room, so they never hide the player.
const LOW_WALL_SCALE := 0.3
const SPIKE_PERIOD := 3.0
const SPIKE_UP_TIME := 1.1
const SPIKE_DOWN_Y := -1.95
## How much longer a path through a spike trap counts for skeletons.
const SPIKE_DETOUR := 6.0

var level_name := ""
var hint := ""
var grid: Array[String] = []
var width := 0
var height := 0
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i(-1, -1)
var astar := AStarGrid2D.new()
var player: Node3D
var finished := false
var has_key := false

var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _time := 0.0
var _torches: Array = []
## Lights that always burn: the stairs, shrines and fountains.
var _light_spots: Array[Vector3] = []
## Chance that a wall torch burns when the level starts.
const TORCH_LIT_CHANCE := 0.5
## How far a light reaches far enough to see someone by.
const LIGHT_REACH := 8.0
## How close to a torch's wall the hero must run to reach it.
const TORCH_TOUCH := 1.6
var _spikes: Array = []
var _pickups: Array = []
var interactables: Array = []
## What the hero already took here: ids of searched furniture and picked up
## coins. The game hands in its own dictionary for this level, keeps it in
## the saved game, and calls restore_taken() after build(), so nothing fills
## up again after a reload, a night in bed or a walk out and back in.
var taken := {}
var enemies: Array = []
## Shrines and the safe room's bed, storage chest and merchant: things to run into.
var stations: Array = []
var safe := false
## The world above ground after the last dungeon level: see Outdoor.
var outdoor := false
## Inside a village building: the building's letter on the village map,
## and which floor ("cellar" below, "upstairs" above).
var building := ""
var floor_name := ""
## The hero's name: the cellar shows which vault is theirs.
var hero := ""
var _vault_slots: Array[Vector2i] = []
var _vault_shows: Array = []
var elite := false
## A dungeon of its own below a village building's door (see "lair: yes").
var lair := false
## How deep the level lies (0 for the first); deeper skeletons wear more gear.
var depth := 0
var fog: Fog
var _doors: Array = []
var _torch_spots: Array[Vector3] = []
var _walls_body := StaticBody3D.new()
var _door_hint_shown := false
## Hidden walls and the torches that open them. Each lever rolls once,
## the first time the hero walks past it.
var _secrets: Array = []
## The secret room's wealth: one of TIERS.
var secret_tier := "normal"
## Extra chance in percent to notice a lever; the game adds 1 per room found.
var secret_bonus := 0
## Set by the game when the run is overdue a secret room: the lever is
## noticed for sure.
var secret_sure := false
const LEVER_RANGE := 7.0
## How many steps from the secret wall a torch may be to serve as its lever.
const LEVER_STEPS := 10
## Seconds between pulling the lever and the stone starting to move.
const SECRET_DELAY := 2.5
## Per wealth: chance in percent to notice the lever, gold in each chest,
## the cheapest gear a chest may hold, and the colour of its name.
const TIERS := {
	"normal": {"name": "Gewöhnlich", "chance": 55, "gold": 10, "min_price": 0, "color": Color(0.85, 0.85, 0.85)},
	"ungewoehnlich": {"name": "Ungewöhnlich", "chance": 40, "gold": 18, "min_price": 15, "color": Color(0.45, 0.9, 0.4)},
	"selten": {"name": "Selten", "chance": 28, "gold": 30, "min_price": 25, "color": Color(0.35, 0.6, 1.0)},
	"episch": {"name": "Episch", "chance": 18, "gold": 45, "min_price": 34, "color": Color(0.75, 0.4, 1.0)},
	"gottgeboren": {"name": "Gottgeboren", "chance": 10, "gold": 70, "min_price": 42, "color": Color(1.0, 0.6, 0.15)},
}
## English names for the secret tiers, accepted in level files.
const TIER_ALIASES := {"common": "normal", "uncommon": "ungewoehnlich", "rare": "selten", "epic": "episch", "godborn": "gottgeboren"}
## Every wall torch, with the tile it lights, and the plain walls without one.
var _wall_torches: Array = []
var _bare_walls: Array = []
## A secret wall's lever is picked from at least this many torches.
const LEVER_CHOICES := 3


## Whether a level file describes the open air (built by Outdoor).
static func is_outdoor_file(path: String) -> bool:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("outdoor:"):
			return true
	return false


func load_from_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		line = line.strip_edges(false, true)
		if line.begins_with("name:"):
			level_name = line.substr(5).strip_edges()
		elif line.begins_with("hint:"):
			hint = line.substr(5).strip_edges()
		elif line.begins_with("safe:"):
			safe = true
		elif line.begins_with("elite:"):
			elite = true
		elif line.begins_with("building:"):
			# A floor inside a village building (see Outdoor): safe, and its
			# stairs lead back out of the building's door.
			building = line.substr(9).strip_edges()
			safe = true
		elif line.begins_with("lair:"):
			lair = true
		elif line.begins_with("floor:"):
			floor_name = line.substr(6).strip_edges()
		elif line.begins_with("outdoor:"):
			# Out in the open (see Outdoor): no enemies, like a safe room.
			outdoor = true
			safe = true
		elif line.begins_with("secret:"):
			secret_tier = line.substr(7).strip_edges()
			secret_tier = TIER_ALIASES.get(secret_tier, secret_tier)
			if not TIERS.has(secret_tier):
				push_warning("Unknown secret tier: " + secret_tier)
				secret_tier = "normal"
		elif line != "":
			grid.append(line)
			width = maxi(width, line.length())
	height = grid.size()
	if lair:
		# Monsters live down there: not a safe room, even below a building.
		safe = false


func build() -> void:
	_rng.seed = hash(level_name)
	_clear_passages()
	add_child(_walls_body)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "#":
				continue
			_build_floor(c, ch)
			_build_walls(c)
			_build_content(c, ch)
	_build_corner_pillars()
	_pick_levers()
	_build_wall_collision()
	_setup_astar()
	for c in _heavy_starts:
		add_stone(StoneBlock.cell_for(cell_to_world(c), true), true, 0, true)
	refresh_stone_paths()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	_walls_body.add_child(floor_shape)
	fog = Fog.new()
	fog.setup(self)
	add_child(fog)
	_spawn_enemies()
	if lair:
		_decorate_lair()
	if not outdoor and (building == "" or lair):
		add_child(DungeonLife.new(self))
	if not _vault_slots.is_empty():
		refresh_vaults()


# --- Keeping the way free ---------------------------------------------------

## Furniture that stands on a whole tile and cannot be walked through.
const FURNITURE := "bxotkCHBLVFfy"
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Moves furniture out of the way: nothing may stand in a narrow passage, next
## to a door, the stairs or the start, or cut off any part of the level.
func _clear_passages() -> void:
	for round in 20:
		var blocker := _find_blocker()
		if blocker.x < 0:
			return
		var ch := cell_char(blocker)
		_set_cell(blocker, ".")
		var spot := _free_spot_near(blocker)
		if spot.x >= 0:
			_set_cell(spot, ch)


func _find_blocker() -> Vector2i:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if FURNITURE.contains(cell_char(c)) and _crowds_passage(c):
				return c
	# Anything still cut off: free the furniture next to it.
	var reach := _reachable()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if _walkable(c) and not reach.has(c):
				for d in DIRS:
					if FURNITURE.contains(cell_char(c + d)):
						return c + d
	return Vector2i(-1, -1)


## Is this tile, or a tile next to it, a doorway, the stairs, the start or a
## one tile wide gap?
func _crowds_passage(c: Vector2i) -> bool:
	if _is_narrow(c):
		return true
	for d in DIRS:
		var n := c + d
		if "DEP?".contains(cell_char(n)) or (_walkable(n) and _is_narrow(n)):
			return true
	return false


func _is_narrow(c: Vector2i) -> bool:
	var wall := func(o: Vector2i) -> bool: return cell_char(c + o) == "#"
	return (wall.call(Vector2i(1, 0)) and wall.call(Vector2i(-1, 0))) \
			or (wall.call(Vector2i(0, 1)) and wall.call(Vector2i(0, -1)))


func _walkable(c: Vector2i) -> bool:
	var ch := cell_char(c)
	return ch != "#" and not FURNITURE.contains(ch)


## Every tile the hero can reach from the start, walking through doors.
func _reachable() -> Dictionary:
	var start := Vector2i(-1, -1)
	for y in height:
		var x := grid[y].find("P")
		if x >= 0:
			start = Vector2i(x, y)
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in DIRS:
			var n := c + d
			if _walkable(n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen


## The nearest plain floor tile where the furniture blocks nothing.
func _free_spot_near(from: Vector2i) -> Vector2i:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	var i := 0
	while i < todo.size():
		var c := todo[i]
		i += 1
		if ".,".contains(cell_char(c)) and c != from and not _crowds_passage(c):
			var count := _reachable().size()
			_set_cell(c, "x")
			var ok := _reachable().size() == count - 1
			_set_cell(c, ".")
			if ok:
				return c
		for d in DIRS:
			var n := c + d
			if _walkable(n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return Vector2i(-1, -1)


func _set_cell(c: Vector2i, ch: String) -> void:
	var row := grid[c.y]
	grid[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


# --- Grid helpers -----------------------------------------------------------

func cell_char(c: Vector2i) -> String:
	if c.y < 0 or c.y >= height or c.x < 0 or c.x >= grid[c.y].length():
		return "#"
	var ch := grid[c.y][c.x]
	return "#" if ch == " " else ch


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE, 0.0, c.y * TILE)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE), roundi(p.z / TILE))


## A wall tile is "low" when the room lies north of it, i.e. it stands between
## the camera and the floor.
func _is_low_wall(c: Vector2i) -> bool:
	# A secret wall counts as wall here: the wall below it stays full height
	# and gives nothing away.
	return cell_char(c) == "#" and not "#?".contains(cell_char(c + Vector2i(0, -1)))


func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, SOLID.contains(cell_char(c)))
	# Skeletons go around spike traps when there is another way.
	for s in _spikes:
		astar.set_point_weight_scale(s.cell, SPIKE_DETOUR)


# --- Building ---------------------------------------------------------------

func _place(piece: String, pos: Vector3, rot_y := 0.0, parent: Node = self) -> Node3D:
	if KIT_PIECES.has(piece):
		return _place_kit(KIT_PIECES[piece], pos, rot_y, parent)
	if not _scenes.has(piece):
		_scenes[piece] = load(ASSET_DIR + piece + ".glb")
	var node: Node3D = _scenes[piece].instantiate()
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	if piece in TINTED_PIECES:
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mi.name == "spikes":
				# Dull, hammered iron spikes (they move, so the grain rides along).
				GearLook.apply(mi, "metal", SPIKE_IRON, true, 0.35)
			elif mi.name == "wall_doorway_door":
				mi.material_override = _tinted(mi.get_active_material(0))
			else:
				mi.material_override = _rough_stone(mi.get_active_material(0), piece in ["floor_tile_big_spikes", "floor_tile_big_grate"])
	return node


func _place_kit(parts: Array, pos: Vector3, rot_y: float, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	for part in parts:
		_add_kit_part(part, node)
	return node


func _add_kit_part(part: Array, parent: Node3D) -> Node3D:
	var model: String = part[0]
	if not _scenes.has(model):
		_scenes[model] = load(KIT_DIR + model + ".fbx")
	var kit: Node3D = _scenes[model].instantiate()
	kit.position = part[2]
	kit.scale = part[3]
	kit.rotation.y = part[4]
	parent.add_child(kit)
	var mat := _kit_material(part[1])
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var skeleton := mi.get_parent() as Skeleton3D
		if skeleton:
			# The chests come rigged, and the rig shows only the lid, tipped
			# on its back: use the plain mesh, standing upright, instead.
			var plain := MeshInstance3D.new()
			plain.mesh = mi.mesh
			kit.add_child(plain)
			skeleton.get_parent().queue_free()
			mi = plain
		mi.material_override = mat
	return kit


## The darkened cartoon stone, made rough and matt like the kit's walls, so
## spike and grate tiles, stairs and doorways do not look like plastic.
## grey: plain grey stone like the kit's floor tiles (for spike and grate tiles).
func _rough_stone(mat: Material, grey := false) -> Material:
	var key := "mat_rough_stone_grey" if grey else "mat_rough_stone"
	if not _scenes.has(key):
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", (mat as StandardMaterial3D).albedo_texture)
		stone.set_shader_parameter("albedo_color", FLOOR_GREY if grey else STONE_TINT)
		stone.set_shader_parameter("desaturate", 1.0 if grey else 0.0)
		stone.set_shader_parameter("use_normal_map", false)
		stone.set_shader_parameter("strength", 1.4)
		_scenes[key] = stone
	return _scenes[key]


func _tinted(mat: Material) -> Material:
	# All KayKit pieces share one texture, so one darkened copy serves them all.
	if not _scenes.has("mat_tinted"):
		var m: StandardMaterial3D = mat.duplicate()
		m.albedo_color = STONE_TINT
		_scenes["mat_tinted"] = m
	return _scenes["mat_tinted"]


const STONE_SHADER := preload("res://shaders/stone.gdshader")


func _kit_material(set_name: String) -> Material:
	var key := "mat_" + set_name
	if not _scenes.has(key) and set_name == "walls":
		# Walls get rough, stained stone instead of the kit's smooth brick faces.
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", load(KIT_DIR + "walls_albedo.png"))
		stone.set_shader_parameter("normal_tex", load(KIT_DIR + "walls_normal.png"))
		_scenes[key] = stone
	if not _scenes.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(KIT_DIR + set_name + "_albedo.png")
		m.normal_enabled = true
		m.normal_texture = load(KIT_DIR + set_name + "_normal.png")
		m.roughness = 0.9
		_scenes[key] = m
	return _scenes[key]


func _random_quarter_turn() -> float:
	return _rng.randi_range(0, 3) * PI * 0.5


func _build_floor(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	if ch == "S":
		var tile := _place("floor_tile_big_spikes", pos)
		var spikes: Node3D = tile.find_child("spikes", true, false)
		spikes.position.y = SPIKE_DOWN_Y
		_spikes.append({"node": spikes, "cell": c, "phase": c.x * 0.45 + c.y * 0.2})
		return
	var piece := "floor_tile_large"
	var roll := _rng.randf()
	if ch == ",":
		piece = "floor_dirt_large"
	elif roll < 0.07:
		piece = "floor_tile_big_grate"
	elif roll < 0.14:
		piece = "floor_dirt_large"
	_place(piece, pos, _random_quarter_turn())


func _build_walls(c: Vector2i) -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = c + d
		if cell_char(n) == "?" and cell_char(c) != "?":
			_build_secret_face(c, d)
			continue
		if cell_char(n) != "#":
			continue
		if d == Vector2i(0, -1) and cell_char(c) == "E":
			continue # The stairs lead out through the north wall.
		var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
		# Each wall piece faces into the room.
		var rot := atan2(-float(d.x), -float(d.y))
		var low := _is_low_wall(n)
		var piece := "wall"
		var roll := _rng.randf()
		if not low and d == Vector2i(0, -1):
			if roll < 0.12:
				piece = "wall_shelves"
			elif roll < 0.22:
				piece = "wall_archedwindow_gated"
			elif roll < 0.32:
				piece = "wall_cracked"
		elif not low and roll < 0.2:
			piece = "wall_cracked"
		var wall := _place(piece, pos, rot)
		if (c.x + c.y + d.x + d.y) % 2 != 0:
			wall.position.y += 0.02
		if cell_char(c) == "?":
			# The passage's own side walls stay hidden until it opens.
			wall.visible = false
			_secret_at(c).inner.append(wall)
			continue
		if piece == "wall_shelves":
			var facing := Vector3(sin(rot), 0, cos(rot))
			var shelf := _add_interactable("Regal", pos + facing * 1.2, pos + facing * 0.9 + Vector3(0, 3.4, 0), c)
			shelf.touch_cell = n
		if low:
			wall.scale.y = LOW_WALL_SCALE
			continue
		# No torch behind a barrel, crate or table: the hero must reach it.
		var torch: Node3D = null
		# A guardian's hall has no wall torches: only its fire bowl lights
		# the middle, and the rim stays dark for the hero to creep along.
		if not FURNITURE.contains(cell_char(c)) and not _near_guardian(c):
			torch = _maybe_add_torch(pos, rot)
		if torch != null:
			_wall_torches.append({"holder": torch, "cell": c, "pos": pos, "rot": rot})
		elif piece == "wall" and _rng.randf() < 0.18:
			_add_kit_part(WALL_DECOR[_rng.randi() % WALL_DECOR.size()], wall)
		elif piece == "wall" and cell_char(c) != "?" and not FURNITURE.contains(cell_char(c)):
			_bare_walls.append({"cell": c, "pos": pos, "rot": rot})


func _build_corner_pillars() -> void:
	for vy in range(0, height + 1):
		for vx in range(0, width + 1):
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			var walls := 0
			var low := false
			for cc in cells:
				if cell_char(cc) == "#" or cell_char(cc) == "?":
					walls += 1
					low = low or _is_low_wall(cc)
			var diagonal := walls == 2 and ("#?".contains(cell_char(cells[0]))) == ("#?".contains(cell_char(cells[3])))
			if walls == 1 or diagonal:
				var pillar := _place("pillar", Vector3(vx * TILE - TILE * 0.5, 0, vy * TILE - TILE * 0.5))
				if low:
					pillar.scale.y = LOW_WALL_SCALE


func _build_wall_collision() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			var near_floor := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if cell_char(c + Vector2i(dx, dy)) != "#":
						near_floor = true
			if near_floor:
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))


func _add_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	return shape


func _add_solid(pos: Vector3, size: Vector3) -> void:
	_add_box(_walls_body, pos + Vector3(0, size.y * 0.5, 0), size)


func _build_content(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	match ch:
		"P":
			start_cell = c
		"E":
			exit_cell = c
			_build_exit(c)
		"K":
			_build_key(pos)
		"f":
			_build_fire_bowl(pos)
		"c":
			_build_coin(pos)
		"C":
			_build_chest(c)
		"D":
			_build_door(c)
		"b":
			_place("barrel_large", pos + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4)), _rng.randf() * TAU)
			_place("barrel_small", pos + Vector3(1.2, 0, 1.1), _rng.randf() * TAU)
			_add_solid(pos, Vector3(2.4, 2, 2.4))
			_add_interactable("Fass", pos, pos + Vector3(0, 2.8, 0), c)
		"x":
			_place("crates_stacked", pos, _random_quarter_turn())
			_add_solid(pos, Vector3(3.0, 2, 3.0))
			_add_interactable("Kiste", pos, pos + Vector3(0, 3.6, 0), c)
		"k":
			_place("trunk_large_A", pos, _random_quarter_turn())
			_add_solid(pos, Vector3(2.4, 1.5, 2.4))
			var trunk := _add_interactable("Truhe", pos, pos + Vector3(0, 2.4, 0), c)
			if _in_secret_room(c):
				trunk.loot = _secret_loot(c, 0.5)
		"o":
			_place("pillar_decorated", pos)
			_add_solid(pos, Vector3(1.6, 4, 1.6))
		"y":
			_place_lair("Statue_Horse", pos, _random_quarter_turn(), 0.62)
			_add_solid(pos, Vector3(2.6, 4, 2.6))
		"H":
			_build_shrine(c)
		"B":
			var bed_rot := _facing_room(c)
			_place("bed_decorated", pos, bed_rot)
			_add_solid(pos, Vector3(3.2, 1.5, 3.2))
			stations.append({"kind": "bett", "cell": c, "pos": pos, "rot": bed_rot, "used": false})
		"L":
			_place("chest", pos, _facing_room(c))
			_add_solid(pos, Vector3(2.4, 1.5, 2.4))
			stations.append({"kind": "lager", "cell": c, "pos": pos, "used": false})
		"V":
			_build_merchant(c)
		"=":
			_build_bars(c)
		"_":
			_build_plate(c)
		"|":
			_build_gate(c)
		"Q":
			_heavy_starts.append(c)
		"U":
			_vault_slots.append(c)
		"F":
			_build_fountain(c)
		"?":
			_secret_at(c)
		"t":
			_place("table_medium_decorated_A", pos, _random_quarter_turn())
			_add_solid(pos, Vector3(3.0, 2, 2.2))
			_add_interactable("Tisch", pos, pos + Vector3(0, 2.8, 0), c)


func _has_cell(ch: String) -> bool:
	for row in grid:
		if row.contains(ch):
			return true
	return false


## Whether a cell lies within a guardian's hall (a few tiles of a W).
func _near_guardian(c: Vector2i) -> bool:
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			if cell_char(c + Vector2i(dx, dy)) == "W":
				return true
	return false


## A standing fire bowl: a low stone base with a burning fire that always
## lights the tiles around it.
func _build_fire_bowl(pos: Vector3) -> void:
	var base := _place("pillar", pos)
	base.scale = Vector3(1.0, 0.28, 1.0)
	var flame := Effects.make_flame()
	flame.position = pos + Vector3(0, 1.3, 0)
	flame.scale = Vector3.ONE * 2.2
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.28)
	light.light_energy = 4.5
	light.omni_range = 11.0
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, 2.2, 0)
	add_child(light)
	_add_solid(pos, Vector3(1.8, 2, 1.8))
	_light_spots.append(pos)


func _maybe_add_torch(wall_pos: Vector3, rot: float, forced := false) -> Node3D:
	for spot in _torch_spots:
		if spot.distance_to(wall_pos) < TILE * 2.2 and not forced:
			return null
	_torch_spots.append(wall_pos)
	var facing := Vector3(sin(rot), 0, cos(rot))
	var holder := Node3D.new()
	holder.position = wall_pos + facing * 0.5 + Vector3(0, 2.3, 0)
	holder.rotation.y = rot
	add_child(holder)
	_place("torch_mounted", Vector3.ZERO, 0.0, holder)
	var flame := Effects.make_flame()
	flame.position = Vector3(0, 0.78, 0.45)
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.56, 0.24)
	light.light_energy = 3.4
	light.omni_range = 12.0
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 1.0, 1.0)
	holder.add_child(light)
	# Some torches burn, some are cold: a new mix every run.
	var torch := {"light": light, "flame": flame, "holder": holder, "wall_pos": wall_pos, "seed": _rng.randf() * 100.0, "on": true, "touched": -10.0}
	_torches.append(torch)
	set_torch(torch, randf() < TORCH_LIT_CHANCE)
	return holder


## Lights or puts out a torch.
func set_torch(torch: Dictionary, on: bool) -> void:
	torch.on = on
	torch.light.visible = on
	torch.flame.visible = on
	torch.flame.emitting = on


## The torch on the wall the hero runs into, only when the run against the
## wall starts (not while pressing on). Empty otherwise.
func torch_touched(point: Vector3) -> Dictionary:
	for t in _torches:
		if not is_instance_valid(t.holder):
			continue
		if Vector2(point.x - t.wall_pos.x, point.z - t.wall_pos.z).length() < TORCH_TOUCH:
			var fresh: bool = _time - t.touched > 0.4
			t.touched = _time
			return t if fresh else {}
	return {}


## Whether a burning torch, the stairs, a shrine or the fountain lights a spot.
func is_lit(pos: Vector3) -> bool:
	for t in _torches:
		if t.on and is_instance_valid(t.light) and _flat_distance(pos, t.light.global_position) < LIGHT_REACH:
			return true
	for spot in _light_spots:
		if _flat_distance(pos, spot) < LIGHT_REACH:
			return true
	return false


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_key(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 1.3, 0)
	add_child(holder)
	var key := _place("key", Vector3(-0.25, 0, 0), 0.0, holder)
	key.scale = Vector3.ONE * 2.2
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.35)
	light.light_energy = 1.8
	light.omni_range = 4.0
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(1.0, 0.85, 0.4)))
	_pickups.append({"node": holder, "kind": "key", "radius": 1.8})


## A small gold coin lying flat on the floor, picked up when the hero walks over it.
func _build_coin(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.03, 0)
	holder.rotation.y = deg_to_rad(hash(Vector2(pos.x, pos.z)) % 360)
	add_child(holder)
	var coin := _place("coin", Vector3.ZERO, 0.0, holder)
	coin.scale = Vector3.ONE * 1.6
	var c := world_to_cell(pos)
	_pickups.append({"node": holder, "kind": "coin", "radius": 1.5, "id": "coin:%d,%d" % [c.x, c.y]})


func _build_chest(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	# Face the chest towards the open side of the room.
	var rot := 0.0
	if cell_char(c + Vector2i(0, 1)) == "#":
		rot = PI
	var chest := _place("chest_gold", pos, rot)
	_add_solid(pos, Vector3(2.0, 1.5, 2.0))
	var obj := _add_interactable("Schatztruhe", pos, pos + Vector3(0, 2.6, 0), c)
	obj.lid = chest.find_child("chest_gold_lid", true, false)
	if _in_secret_room(c):
		obj.loot = _secret_loot(c, 1.0)
		return
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%s:chest:%d:%d" % [level_name, c.x, c.y])
	if _behind_gate(c):
		# The reward of a block-pushing puzzle: as rich as a rare secret room.
		var rare: Dictionary = TIERS["selten"]
		obj.loot = {"gold": int(rare.gold), "item": Items.random_item(loot_rng, int(rare.min_price))}
		return
	obj.loot = {"gold": 5, "item": Items.random_item(loot_rng)}


## The tiles reachable from the start without passing an iron gate (|).
var _ungated := {}


## Whether a tile lies behind an iron gate, shut off until its pressure
## plates are pressed (and not in the secret room).
func _behind_gate(c: Vector2i) -> bool:
	if not _has_cell("|") or _in_secret_room(c):
		return false
	if _ungated.is_empty():
		for y in height:
			var x := grid[y].find("P")
			if x >= 0:
				_ungated[Vector2i(x, y)] = true
		var todo: Array[Vector2i] = []
		todo.assign(_ungated.keys())
		while not todo.is_empty():
			var at: Vector2i = todo.pop_back()
			for d in DIRS:
				var n := at + d
				if not "#?|".contains(cell_char(n)) and not _ungated.has(n):
					_ungated[n] = true
					todo.append(n)
	return not _ungated.has(c)


## Gold and gear for a chest in the secret room, as rich as its tier. A trunk
## gets a share of the gold and, in the richest rooms, gear too.
func _secret_loot(c: Vector2i, share: float) -> Dictionary:
	var tier: Dictionary = TIERS[secret_tier]
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%s:secret:%d:%d" % [level_name, c.x, c.y])
	var loot := {"gold": int(round(tier.gold * share * loot_rng.randf_range(0.8, 1.2)))}
	if share >= 1.0 or tier.min_price >= 34:
		loot.item = Items.random_item(loot_rng, tier.min_price)
	return loot


func _in_secret_room(c: Vector2i) -> bool:
	return not _outer_side().has(c)


## A small stone shrine with a floating, glowing crystal.
func _build_shrine(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var base := _place("pillar", pos)
	base.scale = Vector3(1.2, 0.32, 1.2)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_place("candle_lit", pos + Vector3(cos(a), 0, sin(a)) * 1.25, _rng.randf() * TAU)
	var orb := MeshInstance3D.new()
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.55, 0.8, 0.55)
	orb.mesh = crystal
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.75, 1.0)
	mat.emission_energy_multiplier = 3.0
	orb.material_override = mat
	orb.position = pos + Vector3(0, 2.3, 0)
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.75, 1.0)
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.position = pos + Vector3(0, 2.6, 0)
	add_child(light)
	var motes := Effects.make_sparkles(Color(0.6, 0.85, 1.0))
	motes.position = pos + Vector3(0, 2.0, 0)
	add_child(motes)
	_add_solid(pos, Vector3(2.2, 2, 2.2))
	_light_spots.append(pos)
	stations.append({"kind": "schrein", "cell": c, "pos": pos, "used": false, "orb": orb, "light": light, "motes": motes})


## A turn that points a piece at the open side of its tile.
func _facing_room(c: Vector2i) -> float:
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if not SOLID.contains(cell_char(c + d)):
			return atan2(float(d.x), float(d.y))
	return 0.0


## Carved stone for pieces built in code (the fountain): the rough, matt stone
## shader on a plain colour, so its stains, grain and pits give the stone its
## look without a kit texture. Shared per colour.
func _plain_stone(color: Color) -> Material:
	var key := "mat_plain_stone_" + color.to_html()
	if not _scenes.has(key):
		if not _scenes.has("tex_white"):
			var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
			img.fill(Color.WHITE)
			_scenes["tex_white"] = ImageTexture.create_from_image(img)
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", _scenes["tex_white"])
		stone.set_shader_parameter("albedo_color", color)
		stone.set_shader_parameter("use_normal_map", false)
		stone.set_shader_parameter("strength", 1.7)
		_scenes[key] = stone
	return _scenes[key]


const WATER_SHADER := preload("res://shaders/water.gdshader")

## The healing fountain: an eight-sided basin of matt carved stone on a low
## step, a column with a small bowl on top, and a spout whose water falls
## back into the basin. The water glows faintly and breathes, with a few
## motes drifting over it, since it heals.
func _build_fountain(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var stone := _plain_stone(Color(0.56, 0.54, 0.5))
	# The inside of the basin stays wet and dark.
	var wet := _plain_stone(Color(0.3, 0.31, 0.32))
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	var still := ShaderMaterial.new()
	still.shader = WATER_SHADER
	still.set_shader_parameter("rings", 0.3)
	still.set_shader_parameter("ring_spacing", 45.0)
	# [inner radius, outer radius, bottom, top, sides, material]
	var parts := [
		[0.0, 1.85, 0.0, 0.22, 8, stone],  # the step
		[1.3, 1.55, 0.22, 1.0, 8, stone],  # the basin's wall
		[1.25, 1.68, 1.0, 1.14, 8, stone],  # its coping, a little wider
		[0.0, 1.31, 0.22, 0.4, 8, wet],  # the basin's floor
		[0.0, 1.3, 0.4, 0.92, 24, water],  # the water
		[0.0, 0.46, 0.4, 0.62, 8, stone],  # the column's foot
		[0.0, 0.3, 0.62, 1.94, 8, stone],  # the column
		[0.0, 0.52, 1.94, 2.06, 8, stone],  # its capital
		[0.5, 0.74, 2.06, 2.38, 8, stone],  # the bowl on top
		[0.0, 0.51, 2.06, 2.14, 8, wet],  # the bowl's floor
		[0.0, 0.5, 2.14, 2.3, 24, still],  # the bowl's water
	]
	for part in parts:
		var node := MeshInstance3D.new()
		node.mesh = Effects.ring_mesh(part[0], part[1], part[2], part[3], part[4], part[5])
		node.position = pos
		if part[5] == water or part[5] == still:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	var spray := Effects.make_spray(Color(0.75, 0.92, 0.95))
	spray.position = pos + Vector3(0, 2.3, 0)
	add_child(spray)
	var motes := Effects.make_sparkles(Color(0.6, 0.9, 0.9))
	motes.amount = 8
	motes.emission_sphere_radius = 1.1
	motes.position = pos + Vector3(0, 1.2, 0)
	add_child(motes)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.85, 0.85)
	glow.light_energy = 0.9
	glow.omni_range = 6.5
	glow.position = pos + Vector3(0, 1.8, 0)
	add_child(glow)
	# The glow breathes slowly, like the water.
	var tween := glow.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow, "light_energy", 1.15, 2.4)
	tween.tween_property(glow, "light_energy", 0.75, 2.4)
	_add_solid(pos, Vector3(3.2, 2, 3.2))
	_light_spots.append(pos)
	stations.append({"kind": "brunnen", "cell": c, "pos": pos, "used": false})


## A secret passage: a wall tile with a fake wall on each open side.
func _secret_at(c: Vector2i) -> Dictionary:
	for s in _secrets:
		if s.cell == c:
			return s
	var body := StaticBody3D.new()
	add_child(body)
	_add_box(body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))
	_secrets.append({"cell": c, "body": body, "walls": [], "inner": [], "lever": null, "lever_cell": c, "lever_on_wall": false, "faces": [], "rolled": false, "open": false})
	return _secrets[-1]


## One face of a secret wall, seen from the room at c. The face toward the
## part of the level the hero starts in carries the lever torch.
func _build_secret_face(c: Vector2i, d: Vector2i) -> void:
	var secret := _secret_at(c + d)
	var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
	var rot := atan2(-float(d.x), -float(d.y))
	var wall := _place("wall", pos, rot)
	secret.walls.append(wall)
	if d == Vector2i(0, 1):
		wall.scale.y = LOW_WALL_SCALE
	elif _outer_side().has(c):
		secret.faces.append({"cell": c, "pos": pos, "rot": rot})


## Tiles of the room in front of a secret wall, up to LEVER_STEPS steps
## away, without going through a door: where its lever may hang.
func _steps_from_secret(s: Dictionary) -> Dictionary:
	var steps := {}
	var todo: Array[Vector2i] = []
	for face in s.faces:
		steps[face.cell] = 0
		todo.append(face.cell)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if steps[c] >= LEVER_STEPS:
			continue
		for d in DIRS:
			var n := c + d
			if not steps.has(n) and _outer_side().has(n) and cell_char(n) != "D":
				steps[n] = steps[c] + 1
				todo.append(n)
	return steps


## Picks each secret wall's lever from the torches around it, at random, so
## it is a different one every run. With no torch near, the wall gets one.
func _pick_levers() -> void:
	for s in _secrets:
		var steps := _steps_from_secret(s)
		var near: Array = []
		for t in _wall_torches:
			if steps.has(t.cell):
				near.append(t)
		# Too few torches around: hang more on the bare walls nearby.
		var bare := _bare_walls.filter(func(w): return steps.has(w.cell))
		while near.size() < LEVER_CHOICES and not bare.is_empty():
			var w: Dictionary = bare.pop_at(_rng.randi() % bare.size())
			if _torch_spots.any(func(spot): return spot.distance_to(w.pos) < TILE * 1.5):
				continue
			near.append({"holder": _maybe_add_torch(w.pos, w.rot, true), "cell": w.cell, "pos": w.pos, "rot": w.rot})
			_wall_torches.append(near[-1])
		if not near.is_empty():
			var t: Dictionary = near[randi() % near.size()]
			s.lever = t.holder
			s.lever_cell = t.cell
		elif not s.faces.is_empty():
			var face: Dictionary = s.faces[0]
			s.lever = _maybe_add_torch(face.pos, face.rot, true)
			s.lever_cell = face.cell
			s.lever_on_wall = true


var _outer: Dictionary = {}


## Tiles reachable from the start without passing a secret wall.
func _outer_side() -> Dictionary:
	if _outer.is_empty():
		var start := Vector2i(-1, -1)
		for y in height:
			var x := grid[y].find("P")
			if x >= 0:
				start = Vector2i(x, y)
		_outer = {start: true}
		var todo: Array[Vector2i] = [start]
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			for d in DIRS:
				var n := c + d
				if cell_char(n) != "#" and cell_char(n) != "?" and not _outer.has(n):
					_outer[n] = true
					todo.append(n)
	return _outer


## Rolls each lever once, the first time the hero walks past it in view.
func _check_secrets() -> void:
	for s in _secrets:
		if s.rolled or s.lever == null:
			continue
		var torch: Node3D = s.lever
		var d := Vector2(player.global_position.x - torch.global_position.x, player.global_position.z - torch.global_position.z)
		if d.length() > LEVER_RANGE or not has_line_of_sight(player.global_position, cell_to_world(s.lever_cell)):
			continue
		s.rolled = true
		# Walking past a strange torch sharpens the hero's sense for such things.
		player.train("intuition", 3.0)
		if randi_range(1, 100) <= secret_chance():
			player.train("intuition", 12.0)
			_open_secret(s)


## Chance in percent to notice this level's lever.
func secret_chance() -> int:
	return 100 if secret_sure else TIERS[secret_tier].chance + secret_bonus + player.intuition_bonus()


## Whether the hero found this level's secret room.
func secret_opened() -> bool:
	return _secrets.any(func(s): return s.open)


func _open_secret(s: Dictionary) -> void:
	s.open = true
	var torch: Node3D = s.lever
	# The torch tips down like a lever. A moment later the false walls grind
	# down into the floor, somewhere nearby.
	var tween := create_tween()
	tween.tween_property(torch, "rotation:x", deg_to_rad(-30), 0.35).set_trans(Tween.TRANS_BACK)
	var sinking: Array = s.walls + ([torch] if s.lever_on_wall else [])
	tween.tween_callback(func():
		for inner in s.inner:
			inner.visible = true
		# Dust rolls out of the gap while the stone grinds down.
		var dust := Effects.make_sparkles(Color(0.75, 0.62, 0.45), true)
		dust.position = cell_to_world(s.cell) + Vector3(0, 1.0, 0)
		dust.amount = 80
		dust.scale_amount_min = 2.0
		dust.scale_amount_max = 4.0
		add_child(dust)).set_delay(SECRET_DELAY)
	for node in sinking:
		tween.parallel().tween_property(node, "position:y", node.position.y - 4.6, 1.6).set_delay(SECRET_DELAY).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		for node in sinking:
			node.queue_free()
		s.body.queue_free()
		astar.set_point_solid(s.cell, false)
		_set_cell(s.cell, "."))
	secret_found.emit(torch.global_position, cell_to_world(s.cell) + Vector3(0, 2.0, 0))


## A knight who trades behind a little table.
func _build_merchant(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var rot := _facing_room(c)
	var facing := Vector3(sin(rot), 0, cos(rot))
	var knight: Node3D = load("res://assets/characters/Knight.glb").instantiate()
	knight.position = pos - facing * 0.6
	knight.rotation.y = rot
	add_child(knight)
	for part in ["1H_Sword", "2H_Sword", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "Round_Shield", "Knight_Helmet"]:
		var node := knight.find_child(part, true, false)
		if node:
			node.visible = false
	var anim: AnimationPlayer = knight.find_child("AnimationPlayer", true, false)
	anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")
	_place("table_medium_decorated_A", pos + facing * 1.1, rot + PI * 0.5)
	_add_solid(pos, Vector3(3.0, 2, 3.0))
	stations.append({"kind": "haendler", "cell": c, "pos": pos, "used": false})


## The unused station whose cell contains a world position, if any.
func station_at(point: Vector3) -> Dictionary:
	var c := world_to_cell(point)
	for s in stations:
		if s.cell == c and not s.used:
			return s
	return {}


## The closest unused station within reach of a position, if any.
func nearest_station(from: Vector3, max_distance := SEARCH_RANGE) -> Dictionary:
	for s in stations:
		if not s.used and Vector2(from.x - s.pos.x, from.z - s.pos.z).length() <= max_distance:
			return s
	return {}


## A shrine gives only one gift: its crystal goes dark afterwards.
func use_shrine(s: Dictionary) -> void:
	s.used = true
	s.motes.emitting = false
	var burst := Effects.make_sparkles(Color(0.6, 0.85, 1.0), true)
	burst.position = s.orb.position
	add_child(burst)
	var tween := create_tween()
	tween.tween_property(s.light, "light_energy", 0.0, 1.2)
	tween.parallel().tween_property(s.orb.material_override, "emission_energy_multiplier", 0.0, 1.2)
	tween.parallel().tween_property(s.orb.material_override, "albedo_color", Color(0.3, 0.3, 0.35), 1.2)


func _build_door(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var blocks_north_south := cell_char(c + Vector2i(-1, 0)) == "#" and cell_char(c + Vector2i(1, 0)) == "#"
	var rot := 0.0 if blocks_north_south else PI * 0.5
	var door := _place("wall_doorway", pos, rot)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
	add_child(body)
	_add_box(body, Vector3(-1.55, 2, 0), Vector3(1.0, 4, 1))
	_add_box(body, Vector3(1.55, 2, 0), Vector3(1.0, 4, 1))
	var leaf := _add_box(body, Vector3(0, 2, 0), Vector3(2.2, 4, 1))
	_doors.append({"door": door.find_child("wall_doorway_door", true, false), "leaf": leaf, "cell": c, "pos": pos, "open": false})


func _build_exit(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	_place("stairs", pos + Vector3(0, 0, -TILE * 0.5))
	# Pale light falling down the stairs: the way out.
	var light := OmniLight3D.new()
	light.light_color = Color(0.62, 0.78, 1.0)
	light.light_energy = 3.0
	light.omni_range = 10.0
	light.position = pos + Vector3(0, 6.0, -2.5)
	add_child(light)
	_light_spots.append(pos)
	var motes := Effects.make_sparkles(Color(0.7, 0.85, 1.0))
	motes.position = pos + Vector3(0, 2.5, -1.0)
	add_child(motes)


# --- Runtime ----------------------------------------------------------------

## Heroes and skeletons each take up the spot they stand on. Their bodies
## already block each other, but a jump onto a skull, a knockback or a spawn
## can still leave two of them inside each other. Such a pair is pushed apart
## at this speed (metres per second), and neither can strike the other until
## they stand side by side again.
const PUSH_APART_SPEED := 6.0
## How far two bodies may sink into each other before they count as stacked
## (bodies that merely touch must still be able to fight).
const STACK_TOLERANCE := 0.15


## Whether `a` and `b` (the hero or skeletons) stand inside each other or on
## top of each other.
func stacked(a, b) -> bool:
	if a == null or b == null or a == b:
		return false
	if _up_on_crate(a, b):
		return false
	var d: Vector3 = b.global_position - a.global_position
	if absf(d.y) > maxf(a.tall, b.tall) + 0.5:
		return false
	d.y = 0.0
	return d.length() < a.radius + b.radius - STACK_TOLERANCE


func _physics_process(delta: float) -> void:
	_push_apart(delta)


## Pushes overlapping hero and skeletons apart; the lighter one moves more,
## and nobody is pushed through a wall.
func _push_apart(delta: float) -> void:
	var bodies: Array[CharacterBody3D] = []
	if player is Player and not player.dead:
		bodies.append(player)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.is_inside_tree():
			bodies.append(e)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			if _up_on_crate(a, b):
				continue
			var d: Vector3 = b.global_position - a.global_position
			if absf(d.y) > maxf(a.tall, b.tall) + 0.5:
				continue
			d.y = 0.0
			var overlap: float = a.radius + b.radius - d.length()
			if overlap <= 0.02:
				continue
			var away: Vector3 = d.normalized() if d.length() > 0.05 else _free_side(b)
			var weight_a := _push_weight(a)
			var weight_b := _push_weight(b)
			var step := minf(overlap, PUSH_APART_SPEED * delta)
			_shove(a, b, -away * step * weight_b / (weight_a + weight_b))
			_shove(b, a, away * step * weight_a / (weight_a + weight_b))


## Whether the higher of two bodies stands on a crate. A hero up on a
## crate stack may be right above a skeleton's head, but stands on the
## crate, not on the skeleton: they are not stacked, are not pushed apart
## (which would shove the hero off the crates), and may fight.
func _up_on_crate(a, b) -> bool:
	var upper = a if a.global_position.y > b.global_position.y else b
	return upper.has_method("on_crate") and upper.on_crate()


## How hard a body is to push: bigger skeletons weigh more, and a hero
## being moved by the game (up the stairs) does not budge.
func _push_weight(body) -> float:
	if body is Player:
		return 1000.0 if body.frozen else 1.0
	return pow(float(body.tall) / 2.4, 2.0)


## Moves `body` by `motion`, ignoring `other` (they overlap already) but
## stopping at walls, furniture and everyone else.
func _shove(body: CharacterBody3D, other: CharacterBody3D, motion: Vector3) -> void:
	if motion.length() < 0.0001:
		return
	body.add_collision_exception_with(other)
	body.move_and_collide(motion)
	body.remove_collision_exception_with(other)


## A direction to step out of a body standing right on top of another:
## the first side with room, else any.
func _free_side(body: CharacterBody3D) -> Vector3:
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var cell := world_to_cell(body.global_position + d * TILE)
		if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
			return d
	return Vector3.RIGHT

# --- Crates -------------------------------------------------------------------

## Crates lying about on this level (see Crate). Where they lie is not kept
## in the saved game: a level built again has only the crates it starts with.
var crates: Array = []
## How far the hero reaches to pick up a crate (metres, from their middle).
const CRATE_REACH := 2.4
## How far in front of the hero's middle a crate is set down.
const CRATE_AHEAD := 1.2
## The hero can set a crate on a stack whose top is up to this far above
## their feet.
const CRATE_LIFT := 1.8


func add_crate(pos: Vector3) -> Crate:
	var crate := Crate.new()
	crate.position = pos
	add_child(crate)
	crates.append(crate)
	return crate


## The crate sitting right on top of `crate`, if any.
func crate_on(crate: Crate) -> Crate:
	for other in crates:
		if other != crate and is_instance_valid(other) and absf(other.global_position.y - crate.top()) < 0.1 and crate.covers(other.global_position, -0.1):
			return other
	return null


## The topmost crate of the stack `crate` belongs to.
func stack_top(crate: Crate) -> Crate:
	var top := crate
	for i in Crate.MAX_STACK + 2:
		var above := crate_on(top)
		if above == null:
			break
		top = above
	return top


## Whether the hero or a skeleton stands on top of `crate`.
func _someone_on(crate: Crate) -> bool:
	var bodies: Array = enemies.duplicate()
	bodies.append(player)
	for b in bodies:
		if is_instance_valid(b) and b is Node3D and absf(b.global_position.y - crate.top()) < 0.3 and crate.covers(b.global_position, 0.5):
			return true
	return false


## The crate the hero could pick up now: the nearest one in reach with
## nothing on top and nobody standing on it, or null.
func crate_in_reach(hero: Node3D, near := Vector3.INF) -> Crate:
	var best: Crate = null
	var best_d := INF
	var feet := hero.global_position.y
	for crate in crates:
		if not is_instance_valid(crate):
			continue
		if crate.global_position.y > feet + 2.0 or crate.top() < feet - 1.2:
			continue
		var d := _flat_distance(hero.global_position, crate.global_position)
		if d > CRATE_REACH:
			continue
		if near != Vector3.INF:
			d = _flat_distance(near, crate.global_position) - crate.global_position.y * 0.01
		if d < best_d and crate_on(crate) == null and not _someone_on(crate):
			best = crate
			best_d = d
	return best


## The crate whose footprint (give or take `margin`) a point on the floor
## falls in: the top of its stack. Null when there is none.
func crate_at(point: Vector3, margin := 0.5) -> Crate:
	for crate in crates:
		if is_instance_valid(crate) and crate.covers(point, margin):
			return stack_top(crate)
	return null


## Lifts a crate off the level (into the hero's bag).
func take_crate(crate: Crate) -> void:
	crates.erase(crate)
	crate.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(crate.model, "position:y", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(crate.model, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(crate.queue_free)


## Where a crate set down by a hero facing `ahead` goes: on top of the
## stack in front of them, else onto whatever is in front of them (the
## floor, mostly). Vector3.INF when there is no room there.
func crate_spot(hero: Node3D, ahead: Vector3) -> Vector3:
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.BACK
	var feet := hero.global_position.y
	var spot := hero.global_position + ahead * CRATE_AHEAD
	# A stack right in front: the new crate goes on top of it.
	var column: Array = crates.filter(func(c): return is_instance_valid(c) and c.covers(spot, 0.35) and c.top() > feet - Crate.SIZE * Crate.MAX_STACK - 0.1)
	if not column.is_empty():
		var top: Crate = column[0]
		for c in column:
			if c.top() > top.top():
				top = c
		var count := 1
		var below := top
		while count < Crate.MAX_STACK + 1:
			var under: Crate = null
			for c in column:
				if c != below and absf(c.top() - below.global_position.y) < 0.1:
					under = c
			if under == null:
				break
			below = under
			count += 1
		if count >= Crate.MAX_STACK or top.top() > feet + CRATE_LIFT:
			return Vector3.INF
		spot = Vector3(top.global_position.x, top.top(), top.global_position.z)
	else:
		# Onto whatever lies in front: the floor, or a lower crate stack's
		# side does not count (the room check below catches that).
		var space := get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(Vector3(spot.x, feet + 0.5, spot.z), Vector3(spot.x, -1.0, spot.z))
		if hero is CollisionObject3D:
			ray.exclude = [(hero as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(ray)
		spot.y = hit.position.y if not hit.is_empty() else 0.0
	return spot if crate_fits(spot) else Vector3.INF


## Whether a crate standing at `spot` (the middle of its bottom) would
## touch nothing: no wall, furniture, hero, skeleton or other crate.
func crate_fits(spot: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * (Crate.SIZE - 0.08)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(), spot + Vector3(0, Crate.SIZE * 0.5, 0))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Sets a crate down at a spot from crate_spot().
func put_crate(spot: Vector3) -> Crate:
	var crate := add_crate(spot)
	crate.model.scale = Vector3.ONE * 0.4
	create_tween().tween_property(crate.model, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return crate


# --- Stone blocks ---------------------------------------------------------------

## Stone blocks the hero built with on this level (see StoneBlock).
var stones: Array = []
## Where the blocks stand, as [x, z, layer, along x (1) or z (0)] per block.
## The game hands in its own list for this level and keeps it in the saved
## game; restore_stones() builds them again after build().
var built: Array = []
## How far the hero reaches to take a block back into the bag (metres from
## their middle to the block's middle), how far from them a block can be
## grabbed with the mouse and dragged to, and how far ahead a block from the
## bag is set down.
const STONE_REACH := 2.6
const STONE_DRAG_RANGE := 7.0
const STONE_AHEAD := 1.6


func add_stone(first: Vector2i, x_wise: bool, on_layer: int, is_heavy := false) -> StoneBlock:
	var stone := StoneBlock.new()
	stone.heavy = is_heavy
	stone.place(first, x_wise, on_layer)
	add_child(stone)
	stones.append(stone)
	return stone


## Builds the blocks of the saved game again (once, after build()).
func restore_stones() -> void:
	for entry in built.duplicate():
		if entry is Array and entry.size() >= 4:
			add_stone(Vector2i(int(entry[0]), int(entry[1])), int(entry[3]) == 1, int(entry[2]))
	refresh_stone_paths()


func _sync_built() -> void:
	built.clear()
	for s in stones:
		if is_instance_valid(s) and not s.heavy:
			built.append([s.cell.x, s.cell.y, s.layer, 1 if s.along_x else 0])


## How many layers of blocks stand on a grid cell: the layer a new block
## there would lie on. `except` is left out (the block being moved).
func stone_column(c: Vector2i, except: StoneBlock = null) -> int:
	var h := 0
	for s in stones:
		if s != except and is_instance_valid(s) and s.cells().has(c):
			h = maxi(h, s.layer + 1)
	return h


## The layer a block on these cells would land on: on the highest block
## under either of its two cells, else on the floor.
func stone_layer_for(first: Vector2i, x_wise: bool, except: StoneBlock = null) -> int:
	var h := 0
	for c in StoneBlock.cells_of(first, x_wise):
		h = maxi(h, stone_column(c, except))
	return h


## Whether a block can be taken or moved: nothing lies on it and nobody
## stands on it.
func stone_free(stone: StoneBlock) -> bool:
	for s in stones:
		if s != stone and is_instance_valid(s) and s.layer == stone.layer + 1:
			for c in s.cells():
				if stone.cells().has(c):
					return false
	return not _someone_on(stone)


## Whether a block would fit there: not too high, and touching no wall,
## furniture, crate, hero, skeleton or other block.
func stone_fits(first: Vector2i, x_wise: bool, on_layer: int, except: StoneBlock = null) -> bool:
	if on_layer >= StoneBlock.MAX_LAYERS:
		return false
	var box := BoxShape3D.new()
	box.size = Vector3(StoneBlock.CELL * 2.0, StoneBlock.HEIGHT, StoneBlock.CELL) - Vector3.ONE * 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	var basis := Basis() if x_wise else Basis(Vector3.UP, PI * 0.5)
	query.transform = Transform3D(basis, StoneBlock.spot_of(first, x_wise, on_layer) + Vector3(0, StoneBlock.HEIGHT * 0.5, 0))
	if except != null:
		query.exclude = [except.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Where a block from the bag goes when the hero facing `ahead` sets it
## down: on the grid in front of them, lying across their way (a wall in
## front), on the floor or on top of the blocks there. Empty when there is
## no room or it would lie too high to lift there.
func stone_spot_ahead(hero: Node3D, ahead: Vector3) -> Dictionary:
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.BACK
	var x_wise := absf(ahead.z) >= absf(ahead.x)
	var first := StoneBlock.cell_for(hero.global_position + ahead * STONE_AHEAD, x_wise)
	var on_layer := stone_layer_for(first, x_wise)
	if on_layer * StoneBlock.HEIGHT > hero.global_position.y + CRATE_LIFT:
		return {}
	if not stone_fits(first, x_wise, on_layer):
		return {}
	return {"cell": first, "along_x": x_wise, "layer": on_layer}


## Where a block dragged to `point` would land, lying along x or z. Empty
## when it is too far from the hero or there is no room.
func stone_drop_spot(stone: StoneBlock, point: Vector3, x_wise: bool, hero: Node3D) -> Dictionary:
	if stone.heavy:
		return _slide_spot(stone, point, hero)
	var first := StoneBlock.cell_for(point, x_wise)
	var spot := StoneBlock.spot_of(first, x_wise, 0)
	var on_layer := stone_layer_for(first, x_wise, stone)
	var result := {"cell": first, "along_x": x_wise, "layer": on_layer, "ok": false}
	if _flat_distance(spot, hero.global_position) > STONE_DRAG_RANGE:
		return result
	if first == stone.cell and x_wise == stone.along_x and on_layer == stone.layer:
		return result
	result.ok = stone_fits(first, x_wise, on_layer, stone)
	return result


## Sets a block down (from the bag) at a spot from stone_spot_ahead().
func put_stone(first: Vector2i, x_wise: bool, on_layer: int) -> StoneBlock:
	var stone := add_stone(first, x_wise, on_layer)
	stone.model.scale = Vector3.ONE * 0.4
	create_tween().tween_property(stone.model, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sync_built()
	refresh_stone_paths()
	return stone


## Lifts a block off the level (into the hero's bag).
func take_stone(stone: StoneBlock) -> void:
	stones.erase(stone)
	_sync_built()
	refresh_stone_paths()
	stone.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(stone.model, "position:y", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(stone.model, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(stone.queue_free)


## The topmost free block whose footprint a point falls in, give or take
## `margin`, or null.
func stone_at(point: Vector3, margin := 0.3) -> StoneBlock:
	var best: StoneBlock = null
	for s in stones:
		if is_instance_valid(s) and s.covers(point, margin) and (best == null or s.layer > best.layer):
			best = s
	return best


## The block the hero could take back into the bag: the nearest free one in
## reach, within lifting height. Null when there is none.
func stone_in_reach(hero: Node3D) -> StoneBlock:
	var best: StoneBlock = null
	var best_d := INF
	var feet := hero.global_position.y
	for s in stones:
		if not is_instance_valid(s) or s.global_position.y > feet + 2.0 or s.top() < feet - 1.2:
			continue
		var d := _flat_distance(hero.global_position, s.global_position)
		if d <= STONE_REACH and d < best_d and stone_free(s):
			best = s
			best_d = d
	return best


## Pushes or throws a block onto another spot: it flies there in an arc,
## while its collision is there at once.
func move_stone(stone: StoneBlock, first: Vector2i, x_wise: bool, on_layer: int) -> void:
	var from := stone.model.global_transform
	stone.place(first, x_wise, on_layer)
	_sync_built()
	refresh_stone_paths()
	var to := Transform3D(Basis() if x_wise else Basis(Vector3.UP, PI * 0.5), stone.global_position)
	var model := stone.model
	model.top_level = true
	model.global_transform = from
	# A heavy block grinds along the floor instead of flying.
	var rise := 0.0 if stone.heavy else 0.6 + 0.12 * from.origin.distance_to(to.origin)
	var fly := func(t: float) -> void:
		if not is_instance_valid(model):
			return
		var q := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), t)
		var p := from.origin.lerp(to.origin, t)
		p.y += rise * 4.0 * t * (1.0 - t)
		model.global_transform = Transform3D(Basis(q), p)
	var tween := create_tween()
	tween.tween_method(fly, 0.0, 1.0, 0.35 + 0.03 * from.origin.distance_to(to.origin))
	tween.tween_callback(func():
		if is_instance_valid(model):
			model.top_level = false
			model.transform = Transform3D())


## The height of the stone surface on the grid cell a point lies in (0 with
## no block there), for climbing onto blocks.
func stone_surface(point: Vector3) -> float:
	return stone_column(StoneBlock.grid_cell(point)) * StoneBlock.HEIGHT


## A heavy block only slides: along the floor, in a straight line along x or
## z from where it lies, as far towards `point` as it goes before it hits
## something (and within the hero's reach). Never turned, never stacked.
func _slide_spot(stone: StoneBlock, point: Vector3, hero: Node3D) -> Dictionary:
	var result := {"cell": stone.cell, "along_x": stone.along_x, "layer": stone.layer, "ok": false}
	if stone.layer != 0:
		return result
	var aim := StoneBlock.cell_for(point, stone.along_x) - stone.cell
	if aim == Vector2i.ZERO:
		return result
	var dir := Vector2i(signi(aim.x), 0) if absi(aim.x) >= absi(aim.y) else Vector2i(0, signi(aim.y))
	var reached := stone.cell
	for i in maxi(absi(aim.x), absi(aim.y)):
		var next := reached + dir
		if _flat_distance(StoneBlock.spot_of(next, stone.along_x, 0), hero.global_position) > STONE_DRAG_RANGE:
			break
		if not _slides_onto(stone, next):
			break
		reached = next
	result.cell = reached
	result.ok = reached != stone.cell
	return result


func _slides_onto(stone: StoneBlock, first: Vector2i) -> bool:
	return stone_layer_for(first, stone.along_x, stone) == 0 and stone_fits(first, stone.along_x, 0, stone)


## Pushes a heavy block one grid cell on along `dir`. False when something
## is in the way or something lies on it.
func push_stone(stone: StoneBlock, dir: Vector2i) -> bool:
	var next := stone.cell + dir
	if stone.layer != 0 or not stone_free(stone) or not _slides_onto(stone, next):
		return false
	move_stone(stone, next, stone.along_x, 0)
	return true


# --- Stone blocks in the way of monsters ----------------------------------------

## Tiles that stone blocks wall off: solid for the path finding of skeletons,
## bandits, villagers and the hero's clicks until the blocks are gone again.
## Skeletons and bandits cannot climb, so a wall one block high keeps them
## out, while the hero steps over it.
var _stone_cut := {}
## How finely a tile is checked for a way past the blocks (samples per side,
## 0.4 m each), how many samples wide a gap must be for a skeleton or bandit
## to squeeze through (1.2 m: they are about that broad), and the smallest
## patch of free floor that counts as a way through.
const CUT_SAMPLES := 10
const CUT_GAP := 3
const CUT_PATCH := 4


## Whether stone blocks wall off this tile (see _stone_cut).
func stone_cut(c: Vector2i) -> bool:
	return _stone_cut.has(c)


## The way along the grid from one tile to another (as close as it gets),
## for everyone who walks by the path finding. Someone standing on a tile
## walled off by blocks can still set out from it.
func grid_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var lift := _stone_cut.has(from)
	if lift:
		astar.set_point_solid(from, false)
	var ids := astar.get_id_path(from, to, true)
	if lift:
		astar.set_point_solid(from, true)
	return ids


## Judges again which tiles the blocks wall off: those they stand on and
## those they walled off before.
func refresh_stone_paths() -> void:
	if stones.is_empty() and _stone_cut.is_empty():
		return
	var covered := {}
	var tiles := {}
	for s in stones:
		if not is_instance_valid(s):
			continue
		for c in s.cells():
			covered[c] = true
			for corner in [Vector2(0.05, 0.05), Vector2(0.75, 0.05), Vector2(0.05, 0.75), Vector2(0.75, 0.75)]:
				tiles[world_to_cell(Vector3(c.x * StoneBlock.CELL + corner.x, 0.0, c.y * StoneBlock.CELL + corner.y))] = true
	for t in _stone_cut.keys():
		tiles[t] = true
	for t in tiles:
		if not astar.is_in_boundsv(t) or (astar.is_point_solid(t) and not _stone_cut.has(t)):
			continue
		var cut := _stone_cuts(t, covered)
		if cut and not _stone_cut.has(t):
			_stone_cut[t] = true
			astar.set_point_solid(t, true)
		elif not cut and _stone_cut.has(t):
			_stone_cut.erase(t)
			astar.set_point_solid(t, false)


## Whether the blocks on a tile cut it: no single patch of floor wide enough
## to walk joins all the sides it can be entered from. A tile split in two
## counts as cut (better a detour than a skeleton stuck at a wall).
func _stone_cuts(t: Vector2i, covered: Dictionary) -> bool:
	var n := CUT_SAMPLES
	var step := TILE / n
	var corner := cell_to_world(t) - Vector3(TILE, 0.0, TILE) * 0.5
	var floor_free := PackedByteArray()
	floor_free.resize(n * n)
	var any_covered := false
	for j in n:
		for i in n:
			var f := not covered.has(StoneBlock.grid_cell(corner + Vector3((i + 0.5) * step, 0.0, (j + 0.5) * step)))
			floor_free[j * n + i] = 1 if f else 0
			if not f:
				any_covered = true
	if not any_covered:
		return false
	# The sides that lead on to floor, north, south, west, east (a tile the
	# blocks wall off counts: the floor is there).
	var open: Array[bool] = []
	for d in DIRS_NSWE:
		var nb: Vector2i = t + d
		open.append(astar.is_in_boundsv(nb) and (not astar.is_point_solid(nb) or _stone_cut.has(nb)))
	# Only wide enough floor counts: a run of CUT_GAP free samples through it
	# along x and along z (running on past an open side).
	var wide_x := PackedByteArray()
	wide_x.resize(n * n)
	var wide_z := PackedByteArray()
	wide_z.resize(n * n)
	for j in n:
		_mark_wide(floor_free, wide_x, j * n, 1, open[2], open[3])
	for i in n:
		_mark_wide(floor_free, wide_z, i, n, open[0], open[1])
	# Patches of walkable floor.
	var comp := PackedInt32Array()
	comp.resize(n * n)
	comp.fill(-1)
	var sizes: Array[int] = []
	for k in n * n:
		if wide_x[k] == 0 or wide_z[k] == 0 or comp[k] >= 0:
			continue
		var id := sizes.size()
		var size := 0
		comp[k] = id
		var todo: Array[int] = [k]
		while not todo.is_empty():
			var q: int = todo.pop_back()
			size += 1
			var qi := q % n
			var qj := (q - qi) / n
			for nb in [q - 1 if qi > 0 else -1, q + 1 if qi < n - 1 else -1, q - n if qj > 0 else -1, q + n if qj < n - 1 else -1]:
				if nb >= 0 and wide_x[nb] == 1 and wide_z[nb] == 1 and comp[nb] < 0:
					comp[nb] = id
					todo.append(nb)
		sizes.append(size)
	# Every open side reached by no patch is a way of its own (a dead end);
	# every patch that reaches a side is one too. More than one: cut.
	var reached := {}
	var ways := 0
	for side in 4:
		if not open[side]:
			continue
		var touched := false
		for m in n:
			var k: int = [m, (n - 1) * n + m, m * n, m * n + n - 1][side]
			if comp[k] >= 0 and sizes[comp[k]] >= CUT_PATCH:
				touched = true
				reached[comp[k]] = true
		if not touched:
			ways += 1
	ways += reached.size()
	return ways >= 2 or reached.is_empty()


## Marks the samples of a line (n samples from `start`, `stride` apart) that
## lie in a run of at least CUT_GAP free ones; a run that touches an open
## end goes on beyond it.
func _mark_wide(floor_free: PackedByteArray, out: PackedByteArray, start: int, stride: int, open_before: bool, open_after: bool) -> void:
	var n := CUT_SAMPLES
	var m := 0
	while m < n:
		if floor_free[start + m * stride] == 0:
			m += 1
			continue
		var first := m
		while m < n and floor_free[start + m * stride] == 1:
			m += 1
		var length := m - first
		if first == 0 and open_before:
			length += CUT_GAP
		if m == n and open_after:
			length += CUT_GAP
		if length >= CUT_GAP:
			for r in range(first, m):
				out[start + r * stride] = 1


# --- Pressure plates and the iron gate ------------------------------------------

## Stone slabs in the floor that sink while a stone block lies on them, and
## the iron gates that sink into the floor for good once all of them do.
var _plates: Array = []
var _gates: Array = []
var _plates_pressed := 0
## Where the level's heavy blocks lie when it starts (tiles marked Q).
var _heavy_starts: Array[Vector2i] = []
const DIRS_NSWE: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## A plate fills the 2x2 build grid cells in the middle of its tile: a block
## lying on any of them presses it.
const PLATE_SIZE := StoneBlock.CELL * 2.0 - 0.1
const PLATE_UP := 0.06


func _build_plate(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(PLATE_SIZE, 0.12, PLATE_SIZE)
	slab.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.38, 0.35)
	mat.roughness = 0.95
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.95, 0.55)
	mat.emission_energy_multiplier = 0.15
	slab.material_override = mat
	slab.position = pos + Vector3(0, PLATE_UP, 0)
	add_child(slab)
	var first := StoneBlock.grid_cell(pos - Vector3(StoneBlock.CELL, 0.0, StoneBlock.CELL) * 0.5)
	var cells: Array[Vector2i] = [first, first + Vector2i(1, 0), first + Vector2i(0, 1), first + Vector2i(1, 1)]
	_plates.append({"cell": c, "cells": cells, "node": slab, "mat": mat, "pressed": false})


func _build_gate(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var across_x := cell_char(c + Vector2i(-1, 0)) == "#" and cell_char(c + Vector2i(1, 0)) == "#"
	var rot := 0.0 if across_x else PI * 0.5
	var bars := _place("wall_gated", pos, rot)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
	add_child(body)
	_add_box(body, Vector3(0, 2, 0), Vector3(TILE, 4, 0.6))
	_gates.append({"cell": c, "node": bars, "body": body, "open": false})


func plate_count() -> int:
	return _plates.size()


func plates_pressed() -> int:
	return _plates_pressed


func gates_open() -> bool:
	return _gates.all(func(g): return g.open)


func _plate_pressed(plate: Dictionary) -> bool:
	for s in stones:
		if is_instance_valid(s) and s.layer == 0:
			for c in s.cells():
				if plate.cells.has(c):
					return true
	return false


func _check_plates() -> void:
	if _plates.is_empty():
		return
	var pressed := 0
	for plate in _plates:
		var down := _plate_pressed(plate)
		if down != plate.pressed:
			plate.pressed = down
			create_tween().tween_property(plate.node, "position:y", 0.0 if down else PLATE_UP, 0.15)
			plate.mat.emission_energy_multiplier = 1.4 if down else 0.15
			Sfx.play(self, "lever" if down else "word_klack", -4.0, plate.node.global_position)
		if down:
			pressed += 1
	if pressed == _plates_pressed:
		return
	_plates_pressed = pressed
	plates_changed.emit(pressed, _plates.size())
	if pressed == _plates.size():
		_open_gates()


## Every plate is pressed: the iron gates grind down into the floor and stay
## there, so taking a block off a plate again shuts nobody in.
func _open_gates() -> void:
	for g in _gates:
		if g.open:
			continue
		g.open = true
		g.body.queue_free()
		astar.set_point_solid(g.cell, false)
		create_tween().tween_property(g.node, "position:y", -4.1, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gate_opened.emit(g.node.global_position)


func _process(delta: float) -> void:
	_time += delta
	for t in _torches:
		if not is_instance_valid(t.light):
			continue
		var s: float = t.seed + _time * 9.0
		t.light.light_energy = 3.4 + sin(s) * 0.25 + sin(s * 2.3) * 0.15
	for s in stations:
		if s.kind != "schrein":
			continue
		s.orb.rotation.y += delta * 1.5
		if not s.used:
			s.orb.position.y = 2.3 + sin(_time * 2.0) * 0.15
	for p in _pickups:
		# Coins lie still on the floor; keys and dropped gear hover and turn.
		if is_instance_valid(p.node) and p.kind != "coin":
			p.node.rotation.y += delta * 2.0
			p.node.position.y += sin(_time * 3.0) * delta * 0.25
	_update_spikes(delta)
	if player == null or finished:
		return
	player.in_shadow = not is_lit(player.global_position)
	_check_pickups()
	_check_doors()
	_check_secrets()
	_check_plates()
	if exit_cell.x >= 0:
		# The stairs fill the whole exit cell: climbing starts at the first step.
		if world_to_cell(player.global_position) == exit_cell:
			finished = true
			exit_reached.emit()


func _spike_is_up(s: Dictionary) -> bool:
	return fposmod(_time + s.phase, SPIKE_PERIOD) < SPIKE_UP_TIME


func _update_spikes(delta: float) -> void:
	for s in _spikes:
		var t := fposmod(_time + s.phase, SPIKE_PERIOD)
		var target := SPIKE_DOWN_Y
		var speed := 4.0
		if t < SPIKE_UP_TIME:
			target = 0.0
			speed = 30.0
		elif t > SPIKE_PERIOD - 0.45:
			target = SPIKE_DOWN_Y + 0.35 # A small twitch warns before they shoot up.
			speed = 10.0
		s.node.position.y = move_toward(s.node.position.y, target, delta * speed * 2.0)
		if player and not finished and _spike_is_up(s) and player.global_position.y < 0.6:
			var sp := cell_to_world(s.cell)
			if absf(player.global_position.x - sp.x) < 1.6 and absf(player.global_position.z - sp.z) < 1.6:
				player_hurt.emit()
		if _spike_is_up(s):
			# Skeletons caught on the spikes get hurt too.
			var sp := cell_to_world(s.cell)
			for e in enemies:
				if is_instance_valid(e) and absf(e.global_position.x - sp.x) < 1.6 and absf(e.global_position.z - sp.z) < 1.6:
					e.hurt_by_trap(sp)


## Whether a tile has spikes that are up or about to shoot up: skeletons
## wait at the edge instead of stepping on.
func spike_danger(c: Vector2i) -> bool:
	for s in _spikes:
		if s.cell == c:
			return fposmod(_time + s.phase, SPIKE_PERIOD) > SPIKE_PERIOD - 0.7 or _spike_is_up(s)
	return false


func is_spike_cell(c: Vector2i) -> bool:
	return _spikes.any(func(s): return s.cell == c)


func _check_pickups() -> void:
	for p in _pickups.duplicate():
		var n: Node3D = p.node
		var d := Vector2(player.global_position.x - n.global_position.x, player.global_position.z - n.global_position.z)
		if d.length() > p.radius:
			p.erase("warned")
			continue
		if p.kind == "item" and player.bag.size() >= player.bag_size():
			if not p.has("warned"):
				p.warned = true
				bag_full.emit()
			continue
		_pickups.erase(p)
		if p.has("id"):
			taken[p.id] = true
		var tween := create_tween()
		tween.tween_property(n, "position:y", n.position.y + 1.5, 0.35).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(n, "scale", Vector3.ONE * 0.01, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(n.queue_free)
		if p.kind == "key":
			key_collected.emit()
		elif p.kind == "item":
			item_collected.emit(p.id)
		else:
			coins_collected.emit(1)


func _check_doors() -> void:
	for d in _doors:
		if d.open:
			continue
		var dist := Vector2(player.global_position.x - d.pos.x, player.global_position.z - d.pos.z).length()
		if dist > 4.6:
			continue
		if not has_key:
			if not _door_hint_shown:
				_door_hint_shown = true
				door_locked.emit()
			continue
		d.open = true
		has_key = false
		d.leaf.queue_free()
		astar.set_point_solid(d.cell, false)
		var tween := create_tween()
		tween.tween_property(d.door, "rotation:y", d.door.rotation.y - deg_to_rad(105), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		door_opened.emit()
	if not has_key and _door_hint_shown:
		# Allow the hint again once the player walked away.
		var far := true
		for d in _doors:
			if not d.open and Vector2(player.global_position.x - d.pos.x, player.global_position.z - d.pos.z).length() < 5.0:
				far = false
		if far:
			_door_hint_shown = false


# --- Searching --------------------------------------------------------------

func _add_interactable(label: String, pos: Vector3, icon_pos: Vector3, c: Vector2i) -> Dictionary:
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%s:%d:%d:%d" % [level_name, c.x, c.y, interactables.size()])
	var roll := loot_rng.randf()
	var loot := {}
	if roll < 0.3:
		loot = {}
	elif roll < 0.62:
		loot = {"gold": loot_rng.randi_range(1, 3)}
	elif roll < 0.75:
		loot = {"knives": 2}
	elif roll < 0.87:
		loot = {"potion": 1}
	else:
		loot = {"item": Items.random_item(loot_rng)}
	var obj := {"label": label, "pos": pos, "icon_pos": icon_pos, "cell": c, "touch_cell": c, "searched": false, "loot": loot, "lid": null,
			"id": "%s:%d,%d" % [label, c.x, c.y]}
	interactables.append(obj)
	return obj


## The closest object within reach of a world position, preferring objects
## that have not been searched yet. Empty when nothing is in reach.
func nearest_interactable(from: Vector3, max_distance := SEARCH_RANGE) -> Dictionary:
	var best := {}
	var best_d := INF
	for obj in interactables:
		var d := Vector2(from.x - obj.pos.x, from.z - obj.pos.z).length()
		if obj.searched:
			d += 1000.0
		if d - (1000.0 if obj.searched else 0.0) <= max_distance and d < best_d:
			best = obj
			best_d = d
	return best


## Marks an object as searched and returns what was inside.
## The unsearched object whose solid cell contains a world position, if any.
func unsearched_at(point: Vector3) -> Dictionary:
	var c := world_to_cell(point)
	var best := {}
	for obj in interactables:
		if obj.touch_cell == c and not obj.searched:
			if best.is_empty() or point.distance_to(obj.pos) < point.distance_to(best.pos):
				best = obj
	return best


func search(obj: Dictionary) -> Dictionary:
	if obj.searched:
		return {}
	obj.searched = true
	taken[obj.id] = true
	if obj.lid:
		create_tween().tween_property(obj.lid, "rotation:x", obj.lid.rotation.x - deg_to_rad(70), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scatter_debris(obj)
	if not obj.loot.is_empty():
		var burst := Effects.make_sparkles(Color(1.0, 0.85, 0.3), true)
		burst.position = obj.icon_pos - Vector3(0, 1.0, 0)
		add_child(burst)
	return obj.loot


## Leaves everything the hero already took as it was left: furniture
## searched (chests with their lids up, debris in front) and coins gone.
func restore_taken() -> void:
	for obj in interactables:
		if not taken.has(obj.id) or obj.searched:
			continue
		obj.searched = true
		if obj.lid:
			obj.lid.rotation.x -= deg_to_rad(70)
		_scatter_debris(obj)
	for p in _pickups.duplicate():
		if p.has("id") and taken.has(p.id):
			_pickups.erase(p)
			p.node.queue_free()


## A coin or two and a torn page left on the floor in front of a searched
## object, toward where the hero stood, so it reads as already gone through.
func _scatter_debris(obj: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(obj.cell) ^ hash(level_name)
	var front := Vector3(player.global_position.x - obj.pos.x, 0, player.global_position.z - obj.pos.z) if player else Vector3.BACK
	front = front.normalized() if front.length() > 0.01 else Vector3.BACK
	var side := front.cross(Vector3.UP)
	var base := Vector3(obj.pos.x, 0.03, obj.pos.z) + front * 1.5
	for i in rng.randi_range(1, 2):
		var coin := _place("coin", base + side * rng.randf_range(-1.0, 1.0) + front * rng.randf_range(-0.3, 0.4), 0.0)
		coin.scale = Vector3.ONE * 1.6
		coin.rotation = Vector3(0, rng.randf() * TAU, 0)
		# Worthless copper, so nobody mistakes it for gold to pick up.
		for mi in coin.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _copper()
	var page := MeshInstance3D.new()
	page.mesh = _torn_page(rng)
	page.position = base + side * rng.randf_range(-0.8, 0.8) + Vector3(0, 0.02, 0)
	page.rotation.y = rng.randf() * TAU
	add_child(page)


static var _copper_material: StandardMaterial3D


func _copper() -> StandardMaterial3D:
	if _copper_material == null:
		_copper_material = StandardMaterial3D.new()
		_copper_material.albedo_color = Color(0.45, 0.24, 0.14)
		_copper_material.metallic = 0.5
		_copper_material.roughness = 0.7
	return _copper_material


static var _page_material: StandardMaterial3D

## A flat scrap of parchment with ragged edges.
func _torn_page(rng: RandomNumberGenerator) -> Mesh:
	if _page_material == null:
		_page_material = StandardMaterial3D.new()
		_page_material.albedo_color = Color(0.62, 0.55, 0.4)
		_page_material.roughness = 1.0
		_page_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var rim: Array[Vector3] = []
	var steps := 14
	for i in steps:
		var a := TAU * i / steps
		# A squashed square: x, z between the corners of a 0.9 x 0.65 sheet.
		var dir := Vector2(cos(a), sin(a))
		var r := 1.0 / maxf(absf(dir.x) / 0.45, absf(dir.y) / 0.32)
		r *= rng.randf_range(0.72, 1.0)
		rim.append(Vector3(dir.x * r, 0, dir.y * r))
	for i in steps:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(rim[i])
		st.add_vertex(rim[(i + 1) % steps])
	var mesh := st.commit()
	mesh.surface_set_material(0, _page_material)
	return mesh


# --- Enemies ----------------------------------------------------------------

func _spawn_enemies() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if Enemy.LETTERS.has(ch):
				var e := Enemy.new()
				e.kind = Enemy.LETTERS[ch]
				e.elite = elite and ch in "MA"
				var gear_chance: float = Enemy.KINDS[e.kind].get("gear_chance", -1.0)
				e.gear = _roll_gear(e.kind, c, gear_chance) if gear_chance != 0.0 else ([] as Array[String])
				e.level = self
				add_child(e)
				e.global_position = cell_to_world(c)
				if e.kind == "waechter":
					e.watch(_guarded_spot())
				e.died.connect(func():
					enemy_killed.emit(e)
					_drop_gear(e, DROP_CHANCE if not e.is_beast() else BEAST_DROP_CHANCE)
					# A monster of the lair leaves a little gold, the dragon a heap.
					var purse: Array = Enemy.KINDS[e.kind].get("purse", [0, 0])
					_drop_coins(e.global_position, randi_range(purse[0], purse[1]))
					# A guardian on a level without a key carries it.
					if e.kind == "waechter" and not has_key and not _has_cell("K"):
						_build_key(Vector3(e.global_position.x, 0, e.global_position.z)))
				enemies.append(e)


## Chance for each piece of gear a skeleton may wear: higher the deeper it lies.
const GEAR_CHANCE := 0.1
const GEAR_CHANCE_PER_LEVEL := 0.05
## Chance that a worn piece drops when its skeleton falls; a monster of the
## lair carries its piece in its belly, so it always drops.
const DROP_CHANCE := 0.1
const BEAST_DROP_CHANCE := 1.0


## The items a skeleton wears: up to two (three for a brute), no specials,
## one per slot. Fixed per level and tile, like the loot in chests.
## What a guardian watches over: its fire bowl, the key, or else the stairs.
func _guarded_spot() -> Vector3:
	for ch in "fKE":
		for y in height:
			for x in width:
				if cell_char(Vector2i(x, y)) == ch:
					return cell_to_world(Vector2i(x, y))
	return Vector3.ZERO


## `chance` overrides the usual odds per piece, and `salt` tells one roll
## from the next on the same tile (a bandit that comes back after a fall).
func _roll_gear(kind: String, c: Vector2i, chance := -1.0, salt := 0) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:gear:%d:%d:%d" % [level_name, c.x, c.y, salt]) if salt > 0 else hash("%s:gear:%d:%d" % [level_name, c.x, c.y])
	var gear: Array[String] = []
	if chance < 0.0:
		chance = GEAR_CHANCE + GEAR_CHANCE_PER_LEVEL * depth
	for i in (3 if kind in ["koloss", "hauptmann"] else 2):
		if rng.randf() >= chance:
			continue
		for attempt in 6:
			var id := Items.random_item(rng)
			var slot: String = Items.ALL[id].slot
			if slot != "spezial" and slot != "buch" and not gear.any(func(g): return Items.ALL[g].slot == slot):
				gear.append(id)
				break
	return gear


func _drop_gear(e: Enemy, chance := DROP_CHANCE) -> void:
	var spot := e.global_position
	var delay := 0.0
	for id in e.gear:
		if randf() < chance:
			_drop_item(id, spot)
			# It clatters onto the floor, one piece after the other.
			Sfx.play_gear(self, id, delay, spot)
			delay += 0.3
			spot += Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))


## Gold coins spilt from a fallen bandit's purse, scattered around the spot.
## Unlike the coins placed by the map they have no id: once picked up they
## are simply gone, and a reload does not bring them back.
func _drop_coins(pos: Vector3, amount: int) -> void:
	for i in amount:
		var holder := Node3D.new()
		var angle := randf() * TAU
		holder.position = Vector3(pos.x, 0.03, pos.z) + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.5, 1.4)
		holder.rotation.y = randf() * TAU
		add_child(holder)
		var coin := _place("coin", Vector3.ZERO, 0.0, holder)
		coin.scale = Vector3.ONE * 1.6
		_pickups.append({"node": holder, "kind": "coin", "radius": 1.5})
	if amount > 0:
		Sfx.play_coins(self, amount, 0.3, pos)


## A worn piece left on the floor, glowing until the hero walks over it.
func _drop_item(id: String, pos: Vector3) -> void:
	var holder := _item_model(id)
	holder.position = Vector3(pos.x, 1.0, pos.z)
	add_child(holder)
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.9, 1.0)
	light.light_energy = 1.4
	light.omni_range = 3.5
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(0.75, 0.9, 1.0)))
	_pickups.append({"node": holder, "kind": "item", "id": id, "radius": 1.6})


## What an item looks like lying about: its own model, or a gem.
func _item_model(id: String) -> Node3D:
	var item: Dictionary = Items.ALL[id]
	var holder := Node3D.new()
	if item.has("model"):
		var model: Node3D = load(item.model).instantiate()
		model.scale = Vector3.ONE * float(item.get("model_scale", 1.6))
		holder.add_child(model)
	else:
		var gem := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.35
		mesh.height = 0.7
		mesh.radial_segments = 6
		mesh.rings = 2
		gem.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = item.get("tint", Color(1.0, 0.8, 0.3))
		mat.metallic = 0.6
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.6
		gem.material_override = mat
		holder.add_child(gem)
	return holder


# --- The dragon's lair ---------------------------------------------------------

## Pieces of Quaternius' Modular Dungeon kit (CC0): cobwebs, skulls, banners,
## heaps of coins and a horse statue for the dragon's lair.
const LAIR_DIR := "res://assets/lair/"


func _place_lair(piece: String, pos: Vector3, rot_y := 0.0, s := 1.0) -> Node3D:
	if not _scenes.has("lair/" + piece):
		_scenes["lair/" + piece] = load(LAIR_DIR + piece + ".fbx")
	var node: Node3D = _scenes["lair/" + piece].instantiate()
	node.position = pos
	node.rotation.y = rot_y
	node.scale = Vector3.ONE * s
	add_child(node)
	return node


## Dresses the lair: cobwebs in the back corners, tattered banners on the back
## walls, skulls on the floor and heaps of gold around the dragon's hoard.
## None of it is in the way. Fixed per level, like the walls.
func _decorate_lair() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "#" or ch == "E":
				continue
			var pos := cell_to_world(c)
			var north := cell_char(c + Vector2i(0, -1)) == "#"
			var west := cell_char(c + Vector2i(-1, 0)) == "#"
			var east := cell_char(c + Vector2i(1, 0)) == "#"
			if north and (west or east) and _rng.randf() < 0.8:
				var side := -1.0 if west else 1.0
				_place_lair("Cobweb" if _rng.randf() < 0.5 else "Cobweb2",
						pos + Vector3(side * (TILE * 0.5 - 0.35), 2.9, -TILE * 0.5 + 0.35), PI * 0.25 * side + PI, 1.4)
			elif north and ch in ".," and _rng.randf() < 0.18:
				_place_lair("Banner", pos + Vector3(0, 0, -TILE * 0.5 + 0.35), 0.0, 0.85)
			if ch in ".," and not north and _rng.randf() < 0.14:
				_place_lair("Skull", pos + Vector3(_rng.randf_range(-1.3, 1.3), 0, _rng.randf_range(-1.3, 1.3)), _rng.randf() * TAU, 0.8)
			if ch == "C":
				# The hoard: gold heaped up around the chest.
				for i in 4:
					var angle := TAU * i / 4.0 + _rng.randf_range(-0.4, 0.4)
					_place_lair("Coin_Pile", pos + Vector3(cos(angle), 0, sin(angle)) * 2.0, _rng.randf() * TAU, _rng.randf_range(7.0, 11.0))


# --- The bank's vault cellar ----------------------------------------------------

## Iron bars across a one tile gap: solid, but you can see through.
func _build_bars(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	_place("wall_gated", pos, 0.0)
	_add_solid(pos, Vector3(TILE, 4, 0.6))


## Fills the vaults behind the bars: one for every hero who rented one, in
## the order they rented, each with a name plate, their gold and treasures.
## The hero's own vault opens when they run into its bars.
func refresh_vaults() -> void:
	for node in _vault_shows:
		if is_instance_valid(node):
			node.queue_free()
	_vault_shows.clear()
	stations = stations.filter(func(s): return s.kind != "tresor")
	var holders := Bank.vault_holders()
	for i in _vault_slots.size():
		var slot := _vault_slots[i]
		var bars := slot + (Vector2i(0, 1) if cell_char(slot + Vector2i(0, 1)) == "=" else Vector2i(0, -1))
		var owner: String = holders[i] if i < holders.size() else ""
		var show := Node3D.new()
		show.position = cell_to_world(slot)
		add_child(show)
		_vault_shows.append(show)
		var plate := Label3D.new()
		plate.text = owner if owner != "" else Lang.t("Zu vermieten")
		plate.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
		plate.font_size = 48
		plate.pixel_size = 0.012
		plate.outline_size = 10
		plate.modulate = Color(1.0, 0.82, 0.4) if owner == hero and owner != "" else Color(0.85, 0.85, 0.9)
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = cell_to_world(bars) - show.position + Vector3(0, 4.3, 0)
		show.add_child(plate)
		if owner == "":
			continue
		var gold := Bank.gold(owner)
		if gold > 0:
			var stack := _place("coin_stack_large", Vector3(1.1, 0, -1.0), 0.4, show)
			stack.scale = Vector3.ONE * clampf(0.6 + gold / 200.0, 0.6, 1.6)
		var items := Bank.vault_items(owner)
		for k in items.size():
			if not Items.ALL.has(items[k]):
				continue
			var thing := _item_model(items[k])
			thing.position = Vector3(-1.2 + (k % 3) * 1.2, 0.8, -1.2 + (k / 3) * 1.1)
			thing.rotation.y = k * 0.7
			show.add_child(thing)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.55)
		glow.light_energy = 1.2
		glow.omni_range = 4.0
		glow.position = Vector3(0, 2.5, 0)
		show.add_child(glow)
		if owner == hero:
			stations.append({"kind": "tresor", "cell": bars, "pos": cell_to_world(bars), "used": false})


## True when nothing blocks the view between two points on the grid.
func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var from := Vector2(a.x, a.z) / TILE
	var to := Vector2(b.x, b.z) / TILE
	var target := Vector2i(roundi(to.x), roundi(to.y))
	var steps := int(from.distance_to(to) * 4.0) + 1
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / steps)
		var c := Vector2i(roundi(p.x), roundi(p.y))
		if c == target:
			break
		if is_opaque(c):
			return false
	return true


func is_opaque(c: Vector2i) -> bool:
	var ch := cell_char(c)
	if ch == "#" or ch == "?":
		return true
	if ch == "D":
		for d in _doors:
			if d.cell == c:
				return not d.open
	return false

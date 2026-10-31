class_name Outdoor
extends Level
## The world above ground, reached by the last stairs of the dungeon: the hero
## steps out of a crypt onto a graveyard, follows a long path through the
## woods and comes to a village. Villagers go about their work there, and
## the village elder gives the hero an empty house with a bed and a chest.
##
## Map legend (one character per 4x4 m tile):
##   #  forest (trees, cannot be crossed)    .  grass         ,  dirt path
##   P  start, in front of the crypt door    ~  pond
##   R  the crypt (a block of tiles)         g  grave         d  dead tree
##   z  graveyard fence                      a  gate in the fence
##   l  lantern on a post                    p  pumpkins      r  rock
##   T  tree                                 t  tree stump with logs
##   e  barrels, crates and sacks            q  well
##   Buildings, each a rectangular block of the same letter:
##   h  house   j  smithy   n  tavern   m  market   u  windmill
##   y  pumpkin field
##   The hero's house: I  stone wall   i  wooden floor (a gap in the
##   walls is the door)   B  bed (save and log out)   L  chest (storage)
##   :  paved square         F  fountain (heals)   x  bench
##   More buildings: s  temple   k  office of the crown   o  post office
##   w  adventurers' guild   b  bank. A building turns its door to the square or path.
##   Villagers: 0 elder, 1 smith, 2 farmer, 3 woodcutter, 4 guard,
##   5 tavern guest, 6 shopkeeper (buys and sells), 7 child, 8 scholar,
##   9 water carrier, K herald of the crown, O priestess, G guild master,
##   M postmaster, Y banker. Now and then the herald calls out news on the square,
##   and the villagers come over to listen.

## A notice for the message line, e.g. when the house is handed over.
signal notice(text: String, duration: float)

const GRAVEYARD_DIR := "res://assets/graveyard/"
const VILLAGE_DIR := "res://assets/village/"
## Tiles anyone can walk on. Everything else is solid.
const WALK := ".,Pai:0123456789KOGMY"
const VILLAGERS := "0123456789KOGMY"
const BLOCK_CHARS := "Rhjnmuskowb"
const HOMES := ["building_home_A_blue", "building_home_B_red", "building_home_A_yellow", "building_home_B_green"]
const BLOCK_MODELS := {
	"R": "crypt", "j": "building_blacksmith_red", "n": "building_tavern_blue",
	"m": "building_market_green", "u": "building_windmill_red",
	"s": "building_church_yellow", "k": "building_castle_blue", "o": "building_home_A_yellow",
	"w": "building_barracks_red", "b": "building_tower_A_blue",
}
## The herald calls out news this often (seconds); the first time sooner.
const BUILDING_NAMES := {
	"b": "die Bank der Krone", "s": "den Tempel", "k": "das Amt der Krone", "w": "die Abenteurergilde",
	"o": "die Post", "j": "die Schmiede", "n": "das Wirtshaus", "m": "den Laden",
}
const HERALD_EVERY := 80.0
const HERALD_FIRST := 25.0
const GRAVES := ["grave_A", "grave_B", "gravestone", "gravemarker_A", "gravemarker_B", "grave_A_destroyed"]
const PROPS := ["barrel", "crate_A_big", "sack", "wheelbarrow", "bucket_water", "resource_lumber", "resource_stone"]
## The village props come as table-top miniatures: this blows them up to
## the hero's size.
const PROP_SCALE := 6.0
## How far from the open ground trees still grow (in tiles).
const FOREST_DEPTH := 4
## Ground pieces are this many tiles across. Each piece is lit by the
## lanterns near it only, so many lanterns can burn at once.
const GROUND_CHUNK := 12
const HOUSE_ROOF_HEIGHT := 3.6
const WALL_HEIGHT := 4.0
## The elder calls the hero over from this far (metres).
const GREET_RANGE := 11.0

var villagers: Array = []
## Has the elder handed the house over yet? Saved games wake up at home.
var house_given := false
## Where the hero wakes up in the house: next to the bed.
var home_spot := Vector3.ZERO
## Fronts of the village buildings: where villagers walk to.
var spots := {"houses": [], "square": [], "well": []}

var _plants := {}
var _house_rect := Rect2i()
var _door_cell := Vector2i(-1, -1)
var _roof: Node3D
var _south_walls: Array = []
var _inside := false
var _entered_once := false
var _marker: Node3D
var _elder: Node3D
var _aabbs := {}
## Buildings with floors of their own: building letter -> level index.
var interiors := {}
## Where each building's door is, by building letter.
var doors := {}
var _herald: Node3D
var _herald_timer := HERALD_FIRST


func build() -> void:
	_rng.seed = hash(level_name)
	add_child(_walls_body)
	_build_ground()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			_build_outdoor_cell(c, cell_char(c))
	_build_blocks()
	_build_forest()
	_build_house()
	_build_wall_collision()
	_setup_astar()
	_flush_plants()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	_walls_body.add_child(floor_shape)
	_spawn_villagers()


# --- Ground -------------------------------------------------------------------

## One mask pixel per tile: red is path, green graveyard soil, both the
## paved square, blue water, alpha open ground (the forest floor is darker).
func _build_ground() -> void:
	var mask := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var fence := _bounds_of("z")
	var square := _bounds_of(":")
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			var path := 1.0 if ",aP".contains(ch) else 0.0
			var soil := 1.0 if (fence.has_point(c) and not ",aP".contains(ch)) or ch == "y" else 0.0
			# Paving stones: path and soil together mean the square.
			if square.has_point(c) and not BLOCK_CHARS.contains(ch):
				path = 1.0
				soil = 1.0
			var wet := 1.0 if ch == "~" else 0.0
			var open := 0.0 if ch == "#" else 1.0
			mask.set_pixel(x, y, Color(path, soil, wet, open))
	# A smoother mask gives softer edges between the tiles.
	mask.resize(width * 4, height * 4, Image.INTERPOLATE_BILINEAR)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/meadow.gdshader")
	mat.set_shader_parameter("ground_mask", ImageTexture.create_from_image(mask))
	mat.set_shader_parameter("grid_size", Vector2(width, height))
	mat.set_shader_parameter("tile", TILE)
	var margin := 10
	var size := GROUND_CHUNK * TILE
	for cy in range(-margin, height + margin, GROUND_CHUNK):
		for cx in range(-margin, width + margin, GROUND_CHUNK):
			var plane := PlaneMesh.new()
			plane.size = Vector2(size, size)
			var piece := MeshInstance3D.new()
			piece.mesh = plane
			piece.material_override = mat
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.position = Vector3((cx - 0.5) * TILE + size * 0.5, 0, (cy - 0.5) * TILE + size * 0.5)
			add_child(piece)


## The smallest rectangle around all tiles of one kind.
func _bounds_of(ch: String) -> Rect2i:
	var r := Rect2i()
	var first := true
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == ch:
				if first:
					r = Rect2i(x, y, 1, 1)
					first = false
				else:
					r = r.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return r


# --- Models -------------------------------------------------------------------

func _model_path(name: String) -> String:
	var path := GRAVEYARD_DIR + name + ".gltf"
	return path if ResourceLoader.exists(path) else VILLAGE_DIR + name + ".gltf"


func _put(name: String, pos: Vector3, rot := 0.0, s := 1.0, parent: Node = self) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(_model_path(name))
	var node: Node3D = _scenes[name].instantiate()
	node.position = pos
	node.rotation.y = rot
	node.scale = Vector3.ONE * s
	parent.add_child(node)
	return node


## Many copies of one model (trees) are drawn together in one go.
func _plant(name: String, pos: Vector3, rot: float, s: float) -> void:
	if not _plants.has(name):
		_plants[name] = []
	_plants[name].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), pos))


func _flush_plants() -> void:
	for name in _plants:
		var scene: Node3D = load(_model_path(name)).instantiate()
		for part in _meshes_of(scene, Transform3D()):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = _plants[name].size()
			for i in mm.instance_count:
				mm.set_instance_transform(i, _plants[name][i] * part[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)
		scene.free()


## Every mesh in a model, with where it sits inside the model.
func _meshes_of(node: Node, xform: Transform3D) -> Array:
	var found := []
	for child in node.get_children():
		if not child is Node3D:
			continue
		var t: Transform3D = xform * child.transform
		if child is MeshInstance3D and child.mesh:
			found.append([child.mesh, t])
		found.append_array(_meshes_of(child, t))
	return found


## The size of a model, measured once.
func _aabb_of(name: String) -> AABB:
	if not _aabbs.has(name):
		var scene: Node3D = load(_model_path(name)).instantiate()
		var box := AABB()
		var first := true
		for part in _meshes_of(scene, Transform3D()):
			var b: AABB = part[1] * (part[0] as Mesh).get_aabb()
			box = b if first else box.merge(b)
			first = false
		scene.free()
		_aabbs[name] = box
	return _aabbs[name]


func _jitter(amount: float) -> Vector3:
	return Vector3(_rng.randf_range(-amount, amount), 0, _rng.randf_range(-amount, amount))


# --- Tiles --------------------------------------------------------------------

func _build_outdoor_cell(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	match ch:
		"P":
			start_cell = c
		"g":
			var grave: String = GRAVES[_rng.randi() % GRAVES.size()]
			_put(grave, pos + Vector3(0, 0, -0.6) + _jitter(0.3), _rng.randf_range(-0.15, 0.15))
			_add_solid(pos + Vector3(0, 0, -0.6), Vector3(2.0, 1.6, 1.0))
		"d":
			var tree: String = ["tree_dead_large", "tree_dead_medium", "tree_dead_small"][_rng.randi() % 3]
			_put(tree, pos + _jitter(0.5), _rng.randf() * TAU, _rng.randf_range(1.1, 1.4))
			_add_solid(pos, Vector3(1.4, 4, 1.4))
		"p":
			_put("pumpkin_orange_jackolantern", pos + Vector3(-0.4, 0, 0.2), _rng.randf_range(-0.5, 0.5))
			_put("pumpkin_orange", pos + Vector3(0.9, 0, -0.5), _rng.randf() * TAU)
			_put("pumpkin_yellow_small", pos + Vector3(0.6, 0, 0.9), _rng.randf() * TAU)
			_add_solid(pos, Vector3(2.4, 1.2, 2.2))
		"l":
			_build_lantern(pos)
		"r":
			var rock: String = ["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3]
			_put(rock, pos + _jitter(0.4), _rng.randf() * TAU, _rng.randf_range(7.0, 9.0))
			_add_solid(pos, Vector3(2.8, 1.6, 2.8))
		"T":
			_build_tree(pos, true)
			_add_solid(pos, Vector3(1.8, 4, 1.8))
		"t":
			_put("tree_single_A_cut", pos + Vector3(-0.6, 0, 0), _rng.randf() * TAU, PROP_SCALE)
			_put("resource_lumber", pos + Vector3(0.9, 0, 0.6), 0.4, PROP_SCALE * 0.8)
			_add_solid(pos, Vector3(2.6, 1.2, 2.6))
		"e":
			for i in 3:
				var prop: String = PROPS[_rng.randi() % PROPS.size()]
				_put(prop, pos + Vector3(-1.0 + i, 0, _rng.randf_range(-0.8, 0.8)), _rng.randf() * TAU, PROP_SCALE)
			_add_solid(pos, Vector3(3.2, 1.5, 2.6))
		"q":
			_put("building_well_yellow", pos, 0.0, 5.0)
			_add_solid(pos, Vector3(3.2, 2, 3.2))
			spots.well.append(pos + Vector3(0, 0, 2.6))
		"z":
			_build_fence(c, false)
		"a":
			_build_fence(c, true)
		"~":
			_add_solid(pos, Vector3(TILE, 1, TILE))
		"y":
			# Rows of pumpkins on dark soil, ready for the harvest.
			for row in 2:
				for col in 2:
					var kind: String = ["pumpkin_orange", "pumpkin_orange", "pumpkin_yellow_small"][_rng.randi() % 3]
					_put(kind, pos + Vector3(-1.0 + col * 2.0, 0, -1.0 + row * 2.0) + _jitter(0.3), _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
			_add_solid(pos, Vector3(TILE * 0.9, 1, TILE * 0.9))
		":":
			spots.square.append(pos)
		"F":
			_build_fountain(c)
			spots.well.append(pos + Vector3(0, 0, 2.6))
		"x":
			_build_bench(c)


## A bench on the square, its seat turned to the fountain.
func _build_bench(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var to := Vector3.ZERO
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == "F":
				to = cell_to_world(Vector2i(x, y)) - pos
	var rot := atan2(to.x, to.z) if to.length() > 0.1 else 0.0
	_put("bench", pos, rot, 1.3)
	_add_solid(pos, Vector3(2.4, 1, 2.4))


## A post with a lantern hanging from its arm, glowing warm.
func _build_lantern(pos: Vector3) -> void:
	_put("post_lantern", pos, 0.0, 1.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = pos + Vector3(0, 2.6, 1.1)
	add_child(light)
	_add_solid(pos, Vector3(0.7, 3, 0.7))


## A leafy tree, or near the graveyard an autumn pine or a bare one.
func _build_tree(pos: Vector3, single := false) -> void:
	var near_crypt := pos.distance_to(cell_to_world(start_cell)) < 13.0 * TILE
	var roll := _rng.randf()
	var rot := _rng.randf() * TAU
	var at := pos + _jitter(0.9 if not single else 0.3)
	if near_crypt and roll < 0.45:
		_plant(["tree_dead_large", "tree_dead_medium"][_rng.randi() % 2], at, rot, _rng.randf_range(1.2, 1.6))
	elif roll < 0.35 or (near_crypt and roll < 0.8):
		_plant(["tree_pine_orange_large", "tree_pine_yellow_large", "tree_pine_orange_medium", "tree_pine_yellow_medium"][_rng.randi() % 4], at, rot, _rng.randf_range(0.9, 1.25))
	elif roll < 0.75 or single:
		_plant(["tree_single_A", "tree_single_B"][_rng.randi() % 2], at, rot, _rng.randf_range(5.5, 7.5))
	else:
		_plant(["trees_A_medium", "trees_B_medium"][_rng.randi() % 2], at, rot, _rng.randf_range(3.0, 3.8))


## Trees on every forest tile close to the open ground. Further in there
## is only the dark forest floor, which the camera never gets to see much of.
func _build_forest() -> void:
	for y in range(-2, height + 2):
		for x in range(-2, width + 2):
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			var depth := _forest_depth(c)
			if depth > FOREST_DEPTH:
				continue
			if _rng.randf() < [1.0, 1.0, 0.9, 0.75, 0.6][depth]:
				_build_tree(cell_to_world(c))


## How many tiles from the nearest open ground (up to FOREST_DEPTH + 1).
func _forest_depth(c: Vector2i) -> int:
	for r in range(1, FOREST_DEPTH + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and cell_char(c + Vector2i(dx, dy)) != "#" \
						and c.x + dx >= 0 and c.y + dy >= 0 and c.x + dx < width and c.y + dy < height:
					return r
	return FOREST_DEPTH + 1


## An iron graveyard fence, running along its neighbours; a gate is an arch.
func _build_fence(c: Vector2i, gate: bool) -> void:
	var pos := cell_to_world(c)
	var across := "zaR".contains(cell_char(c + Vector2i(1, 0))) or "zaR".contains(cell_char(c + Vector2i(-1, 0)))
	var rot := 0.0 if across else PI * 0.5
	var along := Vector3(1, 0, 0) if across else Vector3(0, 0, 1)
	if gate:
		_put("arch_gate", pos, rot)
		_add_solid(pos + along * 1.9, Vector3(0.5, 4, 0.5))
		_add_solid(pos - along * 1.9, Vector3(0.5, 4, 0.5))
		return
	_put("fence" if _rng.randf() < 0.85 else "fence_broken", pos, rot)
	for end in [-1, 1]:
		var key := "pillar_%d_%d" % [roundi((pos.x + along.x * 2 * end) * 10), roundi((pos.z + along.z * 2 * end) * 10)]
		if not _scenes.has(key):
			_scenes[key] = true
			_put("fence_pillar", pos + along * 2.0 * end, rot)
	_add_solid(pos, Vector3(4, 2.2, 0.5) if across else Vector3(0.5, 2.2, 4))


# --- Buildings ----------------------------------------------------------------

## Each block of building tiles gets one building, scaled to fill it.
func _build_blocks() -> void:
	var seen := {}
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not BLOCK_CHARS.contains(ch) or seen.has(c):
				continue
			var block := Rect2i(c, Vector2i.ONE)
			while cell_char(Vector2i(block.end.x, y)) == ch:
				block.size.x += 1
			while cell_char(Vector2i(x, block.end.y)) == ch:
				block.size.y += 1
			for by in range(block.position.y, block.end.y):
				for bx in range(block.position.x, block.end.x):
					seen[Vector2i(bx, by)] = true
			_build_block(ch, block)


func _build_block(ch: String, block: Rect2i) -> void:
	var model: String = HOMES[_rng.randi() % HOMES.size()] if ch == "h" else BLOCK_MODELS[ch]
	var box := _aabb_of(model)
	var facing := _block_facing(block) if ch != "R" else Vector2i(0, 1)
	var rot := atan2(float(facing.x), float(facing.y))
	var turned := facing.x != 0
	var room := Vector2(block.size) * TILE * 0.92
	var model_size := Vector2(box.size.z, box.size.x) if turned else Vector2(box.size.x, box.size.z)
	var s := minf(room.x / model_size.x, room.y / model_size.y)
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var foot := (Vector3(box.position.x + box.size.x * 0.5, 0, box.position.z + box.size.z * 0.5) * s).rotated(Vector3.UP, rot)
	var node := _put(model, center - foot, rot, s)
	var solid := Vector3(block.size.x * TILE * 0.86, 4, block.size.y * TILE * 0.86)
	_add_solid(center, solid)
	var reach := Vector2(block.size) * TILE * 0.5 + Vector2(2.0, 2.0)
	var front := center + Vector3(facing.x * reach.x, 0, facing.y * reach.y)
	doors[ch] = front
	if interiors.has(ch):
		# Run into the door to go in.
		var door := center + Vector3(facing.x * (reach.x - 2.0), 0, facing.y * (reach.y - 2.0))
		stations.append({"kind": "eingang", "building": ch, "name": BUILDING_NAMES.get(ch, ""),
				"cell": world_to_cell(door - Vector3(facing.x, 0, facing.y) * 0.5), "pos": door, "used": false})
	if ch == "h":
		spots.houses.append(front)
	elif ch == "R":
		# A faint cold glow in the crypt door the hero came out of.
		var light := OmniLight3D.new()
		light.light_color = Color(0.6, 0.75, 1.0)
		light.light_energy = 1.4
		light.omni_range = 6.0
		light.position = center + Vector3(0, 2.0, block.size.y * TILE * 0.5 - 1.0)
		add_child(light)
		var motes := Effects.make_sparkles(Color(0.7, 0.85, 1.0))
		motes.position = center + Vector3(0, 2.0, block.size.y * TILE * 0.5 - 0.5)
		add_child(motes)
	elif ch in ["n", "m", "j", "s", "k", "o", "w", "b"]:
		spots.square.append(front)
	if ch == "w":
		# Banners and a rack of weapons by the guild door.
		var side := Vector3(-facing.y, 0, facing.x) * 2.2
		_put("weaponrack", front + side - Vector3(facing.x, 0, facing.y) * 0.8, rot, PROP_SCALE)
		_put("flag_red", front - side - Vector3(facing.x, 0, facing.y) * 0.8, rot, PROP_SCALE)
	elif ch == "k":
		var side := Vector3(-facing.y, 0, facing.x) * 4.0
		for flag in [-1, 1]:
			_put("flag_blue", front + side * flag - Vector3(facing.x, 0, facing.y) * 1.2, rot, PROP_SCALE)
	elif ch == "o":
		# Parcels waiting at the post office.
		var side := Vector3(-facing.y, 0, facing.x) * 2.4
		_put("crate_long_A", front + side - Vector3(facing.x, 0, facing.y) * 1.0, rot, PROP_SCALE)
		_put("crate_open", front - side - Vector3(facing.x, 0, facing.y) * 1.0, rot + 0.3, PROP_SCALE)
	node.set_meta("block", block)


## Which way a building's door looks: towards the square if it borders it,
## else towards a path, else south.
func _block_facing(block: Rect2i) -> Vector2i:
	var best := Vector2i(0, 1)
	var best_score := 0
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var score := 0
		for y in range(block.position.y, block.end.y):
			for x in range(block.position.x, block.end.x):
				var n := Vector2i(x, y) + d
				if block.has_point(n):
					continue
				if cell_char(n) == ":":
					score += 3
				elif cell_char(n) == ",":
					score += 1
		# Doors facing away from the camera are only taken for the square.
		if d.y < 0:
			score = score - 1 if score >= 3 else 0
		if score > best_score:
			best_score = score
			best = d
	return best


# --- The hero's house ---------------------------------------------------------

## Stone walls from the dungeon kit around a wooden floor, under a tiled
## roof. Inside, the roof lifts off and the south wall drops low, like the
## walls in the dungeon, so the camera can look in.
func _build_house() -> void:
	_house_rect = _bounds_of("I")
	if _house_rect.size == Vector2i.ZERO:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/house/wood_floor.jpg")
	wood.uv1_scale = Vector3(2, 2, 2)
	wood.roughness = 0.85
	var plank := PlaneMesh.new()
	plank.size = Vector2(TILE, TILE)
	for y in range(_house_rect.position.y, _house_rect.end.y):
		for x in range(_house_rect.position.x, _house_rect.end.x):
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "I":
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))
				continue
			var floor_piece := MeshInstance3D.new()
			floor_piece.mesh = plank
			floor_piece.material_override = wood
			floor_piece.position = cell_to_world(c) + Vector3(0, 0.03, 0)
			add_child(floor_piece)
			if y == _house_rect.end.y - 1:
				_door_cell = c
			_build_house_walls(c)
			if ch == "B":
				_place("bed_decorated", cell_to_world(c), 0.0)
				_add_solid(cell_to_world(c), Vector3(3.2, 1.5, 3.2))
				stations.append({"kind": "bett", "cell": c, "pos": cell_to_world(c), "used": false})
				home_spot = cell_to_world(c + Vector2i(0, 1))
			elif ch == "L":
				_place("chest", cell_to_world(c), 0.0)
				_add_solid(cell_to_world(c), Vector3(2.4, 1.5, 2.4))
				stations.append({"kind": "lager", "cell": c, "pos": cell_to_world(c), "used": false})
	_build_house_pillars()
	_build_roof()


func _build_house_walls(c: Vector2i) -> void:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if cell_char(c + d) != "I":
			continue
		var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
		var wall := _place("wall", pos, atan2(-float(d.x), -float(d.y)))
		if (c.x + c.y + d.x + d.y) % 2 != 0:
			wall.position.y += 0.02
		# Seen from outside, the inner face of the kit wall would show its
		# back: a second wall faces out.
		var outer := _place("wall", pos + Vector3(d.x, 0, d.y) * 0.02, atan2(float(d.x), float(d.y)))
		if d == Vector2i(0, 1) or c == _door_cell:
			_south_walls.append(wall)
			_south_walls.append(outer)


func _build_house_pillars() -> void:
	for vy in range(_house_rect.position.y + 1, _house_rect.end.y):
		for vx in range(_house_rect.position.x + 1, _house_rect.end.x):
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			var walls := cells.filter(func(cc): return cell_char(cc) == "I").size()
			if walls == 1 or walls == 3:
				var pillar := _place("pillar", Vector3(vx * TILE - TILE * 0.5, 0, vy * TILE - TILE * 0.5))
				if vy == _house_rect.end.y - 1:
					_south_walls.append(pillar)


func _build_roof() -> void:
	var w := (_house_rect.size.x - 1) * TILE + 1.6
	var d := (_house_rect.size.y - 1) * TILE + 1.6
	var tiles := StandardMaterial3D.new()
	tiles.albedo_texture = load("res://assets/house/roof_tiles.jpg")
	tiles.uv1_scale = Vector3(4.0, 3.0, 1)
	tiles.albedo_color = Color(0.85, 0.68, 0.6)
	tiles.roughness = 0.8
	var gable_mat := StandardMaterial3D.new()
	gable_mat.albedo_color = Color(0.36, 0.25, 0.17)
	gable_mat.roughness = 0.9
	_roof = Node3D.new()
	var center := cell_to_world(_house_rect.position) + Vector3(_house_rect.size.x - 1, 0, _house_rect.size.y - 1) * TILE * 0.5
	_roof.position = center + Vector3(0, WALL_HEIGHT, 0)
	add_child(_roof)
	# Two tiled slopes, the ridge running east to west, facing the camera.
	var slope := atan2(HOUSE_ROOF_HEIGHT, d * 0.5)
	var length := Vector2(d * 0.5, HOUSE_ROOF_HEIGHT).length() + 0.3
	for side in [1, -1]:
		var slab := BoxMesh.new()
		slab.size = Vector3(w, 0.3, length)
		var piece := MeshInstance3D.new()
		piece.mesh = slab
		piece.material_override = tiles
		piece.rotation.x = slope * side
		piece.position = Vector3(0, HOUSE_ROOF_HEIGHT * 0.5, d * 0.25 * side)
		_roof.add_child(piece)
	# Wooden gables close the ends.
	for side in [1, -1]:
		var gable := PrismMesh.new()
		gable.size = Vector3(d - 0.4, HOUSE_ROOF_HEIGHT - 0.1, 0.3)
		var piece := MeshInstance3D.new()
		piece.mesh = gable
		piece.material_override = gable_mat
		piece.rotation.y = PI * 0.5
		piece.position = Vector3((w * 0.5 - 0.7) * side, HOUSE_ROOF_HEIGHT * 0.5, 0)
		_roof.add_child(piece)
	# A chimney.
	var stack := BoxMesh.new()
	stack.size = Vector3(1.0, 2.4, 1.0)
	var chimney := MeshInstance3D.new()
	chimney.mesh = stack
	chimney.material_override = _kit_material("walls")
	chimney.position = Vector3(w * 0.25, HOUSE_ROOF_HEIGHT * 0.75, -d * 0.12)
	_roof.add_child(chimney)


func _in_house(c: Vector2i) -> bool:
	return _house_rect.has_point(c) and cell_char(c) != "I"


## A golden glow over the door of the hero's new house.
func _show_house_marker() -> void:
	if _door_cell.x < 0 or _marker != null:
		return
	_marker = Node3D.new()
	_marker.position = cell_to_world(_door_cell) + Vector3(0, 0, 1.0)
	add_child(_marker)
	var motes := Effects.make_sparkles(Color(1.0, 0.85, 0.4))
	motes.position.y = 2.0
	_marker.add_child(motes)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position.y = 3.0
	_marker.add_child(light)


## A saved game wakes up in the house the elder gave.
func wake_at_home() -> void:
	house_given = true
	_entered_once = true


# --- Villagers ----------------------------------------------------------------

func _spawn_villagers() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not VILLAGERS.contains(ch):
				continue
			var v := Villager.new()
			v.setup(self, ch, c)
			add_child(v)
			v.global_position = cell_to_world(c)
			villagers.append(v)
			# The shopkeeper trades like the merchant in the refuge.
			var kind: String = {"6": "haendler", "Y": "bank"}.get(ch, "npc")
			var station := {"kind": kind, "cell": c, "pos": cell_to_world(c), "used": false, "npc": v}
			v.station = station
			stations.append(station)
			if ch == "0":
				_elder = v
			elif ch == "K":
				_herald = v


## Bumping into a villager: they walk around, so their tile is not enough.
## A door is hit anywhere along the front of its building.
func station_at(point: Vector3) -> Dictionary:
	for s in stations:
		if s.has("npc") and _flat_distance(point, s.pos) < 1.6:
			return s
		if s.kind == "eingang" and _flat_distance(point, s.pos) < 2.4:
			return s
	return super(point)


# --- Rules of the open air ----------------------------------------------------

func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not WALK.contains(cell_char(c)))
	# Villagers and the hero keep to the paths where they can.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) == ".":
				astar.set_point_weight_scale(c, 1.6)


## Under the open evening sky everything is lit.
func is_lit(_pos: Vector3) -> bool:
	return true


func is_opaque(c: Vector2i) -> bool:
	var ch := cell_char(c)
	return ch == "#" or ch == "I" or BLOCK_CHARS.contains(ch)


## Whether a tile is walkable ground (for villagers picking where to go).
func is_open(c: Vector2i) -> bool:
	return WALK.contains(cell_char(c)) and not astar.is_point_solid(c)


func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	var cell := world_to_cell(player.global_position)
	var inside := _in_house(cell)
	if inside != _inside:
		_inside = inside
		_roof.visible = not inside
		for wall in _south_walls:
			create_tween().tween_property(wall, "scale:y", LOW_WALL_SCALE if inside else 1.0, 0.35)
		if inside and house_given and not _entered_once:
			_entered_once = true
			notice.emit(Lang.t("Dein neues Zuhause! Im Bett speicherst du, in der Truhe lagerst du deine Schätze."), 4.0)
		if inside and _marker:
			_marker.queue_free()
			_marker = null
	_herald_timer -= delta
	if _herald and _herald_timer <= 0.0:
		_herald_timer = HERALD_EVERY
		_call_the_village()
	if not house_given and _elder and _flat_distance(player.global_position, _elder.global_position) < GREET_RANGE:
		house_given = true
		_elder.greet_newcomer(player)
		_show_house_marker()
		notice.emit(Lang.t("Der Dorfvorsteher schenkt dir das leere Haus. Ein goldenes Licht zeigt dir die Tür."), 4.5)


## The herald rings the news across the square, and everyone in the village
## comes over to listen for a while: a reason to gather.
func _call_the_village() -> void:
	var stand: Vector3 = _herald.global_position
	_herald.proclaim()
	var ring: Array[Vector3] = []
	var at := world_to_cell(stand)
	for dy in range(-1, 5):
		for dx in range(-4, 5):
			var c := at + Vector2i(dx, dy)
			if cell_char(c) == ":" and absi(dx) + absi(dy) >= 2:
				ring.append(cell_to_world(c))
	ring.shuffle()
	var i := 0
	for v in villagers:
		if v == _herald or not v.comes_to_listen() or i >= ring.size():
			continue
		if _flat_distance(v.global_position, stand) > 22.0 * TILE * 0.5:
			continue
		v.gather_at(ring[i], stand)
		i += 1
	if player and _flat_distance(player.global_position, stand) < 30.0:
		notice.emit(Lang.t("Der Herold ruft auf dem Marktplatz aus. Das Dorf kommt zusammen."), 3.0)

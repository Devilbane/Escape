class_name HomeStoreFurniture
extends RefCounted
## The furniture of the two special stores of a home (see HomeStores), built
## from the dungeon kit's chest and simple shapes when the home is built:
##   m  the steel-banded chest: the plain chest under broad bands of dark
##      steel, studded with rivets, with a heavy lock plate on its front.
##   h  the ingredient board: an oak board on the wall with three shelves,
##      phials and flasks of coloured brews, jars with lids, bundles of herbs
##      hanging from a rail at the top and a bucket of water on the floor.
## Each turns its back to a wall beside it and its front to the room (see
## Level._back_to_wall), is solid where it stands and is a station the hero
## runs into to open its window.

const STEEL := Color(0.52, 0.54, 0.58)
const RIVET := Color(0.55, 0.57, 0.6)
const OAK := Color(0.5, 0.35, 0.24)
## How thick the bands are, and how far they stand off the wood.
const BAND := 0.14
const BAND_OFF := 0.035
## The share of the chest's height that is its body, below the lid.
const BODY := 0.58
## The brews in the phials and flasks (alpha: how clear the glass is).
const BREWS := [Color(0.3, 0.8, 0.4, 0.75), Color(0.75, 0.15, 0.2, 0.8), Color(0.35, 0.5, 0.95, 0.75),
		Color(0.9, 0.6, 0.15, 0.75), Color(0.7, 0.3, 0.85, 0.75)]
const HERBS := [Color(0.32, 0.55, 0.22), Color(0.45, 0.6, 0.25), Color(0.55, 0.5, 0.25), Color(0.3, 0.45, 0.3)]
## The board's size across the wall and how high it reaches (metres).
const BOARD_WIDTH := 3.0
const BOARD_HEIGHT := 2.9
const SHELF_DEPTH := 0.7
const SHELVES := [0.95, 1.65, 2.35]


## The steel-banded chest on tile `c`.
static func build_metal_chest(level: Level, c: Vector2i) -> Node3D:
	var pos := level.cell_to_world(c)
	var pivot := Node3D.new()
	pivot.name = "MetalChest"
	pivot.position = pos
	pivot.rotation.y = level._back_to_wall(c, level._facing_room(c))
	level.add_child(pivot)
	var chest := level._place("chest", Vector3.ZERO, 0.0, pivot)
	# A touch darker and greyer than the plain chest, so the two differ at
	# a glance even before the bands are seen.
	_tint(chest, Color(0.62, 0.58, 0.56))
	var box := Level.footprint(chest, pivot)
	if box.size.x < 0.05:
		box = AABB(Vector3(-0.9, 0, -0.6), Vector3(1.8, 1.3, 1.2))
	var steel := _mat(STEEL, 0.4, 0.55)
	var rivet := _mat(RIVET, 0.3, 0.9)
	var mid := box.get_center()
	var front := box.end.z + BAND_OFF
	# The body below the rounded lid gets the steel: straps up its front
	# and back, two rings round it, caps on its corners and rivets.
	var body := box.size.y * BODY
	var foot := box.position.y
	for t: float in [0.18, 0.5, 0.82]:
		var x := box.position.x + box.size.x * t
		for sz: float in [-1.0, 1.0]:
			_add(pivot, _box(Vector3(BAND, body, 0.04)), steel, Vector3(x, foot + body * 0.5, mid.z + sz * (box.size.z * 0.5 + 0.02)))
		for y: float in [0.25, 0.6]:
			_add(pivot, _sphere(0.035), rivet, Vector3(x, foot + body * y, front + 0.02))
	for y: float in [0.1, body - BAND * 0.5]:
		_add(pivot, _box(Vector3(box.size.x + BAND_OFF * 2.0, BAND, box.size.z + BAND_OFF * 2.0)), steel, Vector3(mid.x, foot + y, mid.z))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add(pivot, _box(Vector3(0.1, body, 0.1)), steel,
					Vector3(mid.x + sx * (box.size.x * 0.5 + 0.01), foot + body * 0.5, mid.z + sz * (box.size.z * 0.5 + 0.01)))
	# The lock: a heavy plate with a dark keyhole, where lid meets body.
	var lock_y := foot + body * 0.82
	_add(pivot, _box(Vector3(0.34, 0.4, 0.06)), steel, Vector3(mid.x, lock_y, front + 0.04))
	_add(pivot, _box(Vector3(0.07, 0.14, 0.02)), _mat(Color(0.04, 0.04, 0.05), 0.9), Vector3(mid.x, lock_y - 0.04, front + 0.08))
	level._add_fitted_solid(pivot, pos, 1.5)
	level.stations.append({"kind": HomeStores.STATIONS[HomeStores.METAL], "cell": c, "pos": pos, "used": false})
	return pivot


## The ingredient board on tile `c`, its back on the wall beside it.
static func build_board(level: Level, c: Vector2i) -> Node3D:
	var pos := level.cell_to_world(c)
	var pivot := Node3D.new()
	pivot.name = "IngredientBoard"
	pivot.position = pos
	pivot.rotation.y = level._back_to_wall(c, level._facing_room(c))
	level.add_child(pivot)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("board:%d:%d" % [c.x, c.y])
	var oak := _oak()
	var back := -Level.TILE * 0.5 + 0.1
	var shelf_z := back + 0.06 + SHELF_DEPTH * 0.5
	# The board on the wall, two uprights at its sides and the shelves.
	_add(pivot, _box(Vector3(BOARD_WIDTH, BOARD_HEIGHT, 0.08)), oak, Vector3(0, BOARD_HEIGHT * 0.5, back))
	for sx: float in [-1.0, 1.0]:
		_add(pivot, _box(Vector3(0.12, BOARD_HEIGHT, SHELF_DEPTH + 0.06)), oak, Vector3(sx * (BOARD_WIDTH * 0.5 - 0.06), BOARD_HEIGHT * 0.5, shelf_z))
	for y: float in SHELVES:
		_add(pivot, _box(Vector3(BOARD_WIDTH - 0.1, 0.07, SHELF_DEPTH)), oak, Vector3(0, y, shelf_z))
	# Low shelf: jars with lids and a stoppered flask.
	var jars := [Color(0.62, 0.48, 0.3), Color(0.8, 0.78, 0.7), Color(0.45, 0.32, 0.22)]
	for i in 4:
		var x := -1.05 + i * 0.6 + rng.randf_range(-0.05, 0.05)
		if i == 2:
			_flask(pivot, Vector3(x, SHELVES[0] + 0.035, shelf_z), BREWS[3], 0.16)
			continue
		var jar := _mat(jars[i % jars.size()], 0.85)
		_add(pivot, _cylinder(0.14, 0.13, 0.3), jar, Vector3(x, SHELVES[0] + 0.035 + 0.15, shelf_z))
		_add(pivot, _cylinder(0.15, 0.15, 0.05), _oak(), Vector3(x, SHELVES[0] + 0.035 + 0.32, shelf_z))
	# Middle shelf: a row of phials.
	for i in 7:
		var x := -1.2 + i * 0.4
		_phial(pivot, Vector3(x, SHELVES[1] + 0.035, shelf_z + rng.randf_range(-0.08, 0.08)), BREWS[(i + c.x) % BREWS.size()])
	# Top shelf: big round flasks.
	for i in 3:
		_flask(pivot, Vector3(-0.9 + i * 0.9, SHELVES[2] + 0.035, shelf_z), BREWS[(i * 2 + 1) % BREWS.size()], 0.24)
	# Bundles of herbs hanging from a rail along the top.
	var top := BOARD_HEIGHT - 0.12
	_add(pivot, _box(Vector3(BOARD_WIDTH - 0.2, 0.06, 0.06)), oak, Vector3(0, top, back + 0.25))
	for i in 6:
		var x := -1.25 + i * 0.5
		var herb := _mat(HERBS[(i + c.y) % HERBS.size()], 0.95)
		var length := rng.randf_range(0.42, 0.58)
		_add(pivot, _cylinder(0.008, 0.008, 0.12), _mat(Color(0.75, 0.68, 0.5), 0.9), Vector3(x, top - 0.06, back + 0.25))
		# A bundle hangs head down: wide leaves below, the tied stems above.
		_add(pivot, _cylinder(0.03, 0.16, length), herb, Vector3(x, top - 0.12 - length * 0.5, back + 0.25))
	# A bucket of water and a small keg on the floor in front.
	var bucket: Node3D = load("res://assets/village/bucket_water.gltf").instantiate()
	bucket.scale = Vector3.ONE * 3.0
	bucket.position = Vector3(-0.95, 0, shelf_z + 0.65)
	pivot.add_child(bucket)
	var keg := level._place("barrel_small", Vector3(1.0, 0, shelf_z + 0.55), 0.4, pivot)
	keg.scale = Vector3.ONE * 0.9
	# Solid across the shelves and the things in front, but not the whole tile.
	var depth := SHELF_DEPTH + 1.2
	var centre := pivot.transform * Vector3(0, 0, back + depth * 0.5)
	var size := pivot.transform.basis * Vector3(BOARD_WIDTH, 0, depth)
	level._add_solid(Vector3(centre.x, 0, centre.z), Vector3(absf(size.x), 2.2, absf(size.z)))
	level.stations.append({"kind": HomeStores.STATIONS[HomeStores.PANTRY], "cell": c, "pos": pos, "used": false})
	return pivot


## A slim phial with a cork, standing on `at`.
static func _phial(parent: Node3D, at: Vector3, brew: Color) -> void:
	var glass := _glass(brew)
	_add(parent, _cylinder(0.08, 0.09, 0.3), glass, at + Vector3(0, 0.15, 0))
	_add(parent, _cylinder(0.035, 0.04, 0.1), glass, at + Vector3(0, 0.35, 0))
	_add(parent, _cylinder(0.04, 0.04, 0.06), _mat(Color(0.6, 0.45, 0.28), 0.9), at + Vector3(0, 0.43, 0))


## A round flask with a long neck, standing on `at`.
static func _flask(parent: Node3D, at: Vector3, brew: Color, radius: float) -> void:
	var glass := _glass(brew)
	_add(parent, _sphere(radius), glass, at + Vector3(0, radius, 0))
	_add(parent, _cylinder(radius * 0.22, radius * 0.28, radius * 0.9), glass, at + Vector3(0, radius * 2.3, 0))
	_add(parent, _cylinder(radius * 0.26, radius * 0.26, radius * 0.25), _mat(Color(0.6, 0.45, 0.28), 0.9), at + Vector3(0, radius * 2.85, 0))


static func _glass(brew: Color) -> StandardMaterial3D:
	var glass := _mat(brew, 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(brew, 1.0)
	glass.emission_energy_multiplier = 0.3
	return glass


static func _oak() -> StandardMaterial3D:
	var oak := _mat(OAK, 0.8)
	oak.albedo_texture = load("res://assets/house/wood_floor.jpg")
	oak.uv1_triplanar = true
	oak.uv1_scale = Vector3.ONE * 0.5
	return oak


## Darkens every mesh of a placed piece by `tint` (on copies of its materials).
static func _tint(node: Node3D, tint: Color) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var copy: BaseMaterial3D = mat.duplicate()
				copy.albedo_color = copy.albedo_color * tint
				mi.set_surface_override_material(i, copy)


static func _mat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


static func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

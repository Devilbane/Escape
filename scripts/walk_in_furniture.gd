class_name WalkInFurniture
extends RefCounted
## The furniture of the village buildings one can walk into (see WalkIn), made of plain boxes at load
## time: a ladder up to the floor above in the villagers' houses, and the temple's pews, altar
## and flagstone floor. Their beds are CosyBeds.

## The altar: a block of pale stone (metres across, high, deep) with a cloth over it.
const ALTAR_SIZE := Vector3(1.9, 1.0, 0.9)
## A pew: how deep it is from its front to its back rest, and how far apart two rows stand.
const PEW_DEPTH := 0.7
const PEW_STEP := 1.45
const SEAT := 0.48
const BACK := 1.0
## The ladder: how far apart its rails stand and its rungs climb.
const LADDER_WIDE := 0.5
const RUNG_STEP := 0.32

static var _mats := {}


static func _wood() -> StandardMaterial3D:
	if not _mats.has("wood"):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(VillageHouse.WOOD_TEX)
		mat.albedo_color = Color(0.62, 0.46, 0.34)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
		mat.roughness = 0.85
		_mats["wood"] = mat
	return _mats["wood"]


static func _plain(key: String, colour: Color, roughness := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = roughness
		_mats[key] = mat
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, turn := Basis()) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(turn, at)
	parent.add_child(mi)
	return mi


## A wooden ladder leaning on a side wall from the floor at `floor_y` up to `top` (the floor above);
## `side` is the way to that wall (-1 left, 1 right). Its own origin is at the wall's foot.
static func ladder(floor_y: float, top: float, side: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Ladder"
	var foot := Vector3(-side * 0.35, floor_y, 0)
	var head := Vector3(side * 0.12, top, 0)
	var along := head - foot
	var length := along.length()
	var tilt := Basis(Vector3(0, 0, 1), atan2(-along.x, along.y))
	for z: float in [-LADDER_WIDE * 0.5, LADDER_WIDE * 0.5]:
		_box(root, Vector3(0.07, length, 0.07), (foot + head) * 0.5 + Vector3(0, 0, z), _wood(), tilt)
	var rungs := int(length / RUNG_STEP)
	for i in range(1, rungs):
		var at := foot + along * (float(i) / rungs)
		_box(root, Vector3(0.05, 0.05, LADDER_WIDE), at, _wood())
	# The dark hatch in the floor above it leads up.
	_box(root, Vector3(0.7, 0.02, LADDER_WIDE + 0.3), Vector3(side * -0.1, top - 0.01, 0), _plain("hatch", Color(0.05, 0.035, 0.03)))
	return root


## A floor of stone flags, `size` metres, its top at `y`, in the look of the square (see HouseLooks).
static func flagstones(size: Vector2, y: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Flagstones"
	mi.mesh = mesh
	mi.material_override = HouseLooks.flagstones()
	mi.position.y = y
	return mi


## The altar: a stone block with a white cloth, two candles burning on it.
static func altar() -> Node3D:
	var root := Node3D.new()
	root.name = "Altar"
	var stone := _plain("altar", Color(0.78, 0.75, 0.7))
	_box(root, Vector3(ALTAR_SIZE.x, 0.12, ALTAR_SIZE.z), Vector3(0, 0.06, 0), stone)
	_box(root, ALTAR_SIZE - Vector3(0.2, 0.2, 0.2), Vector3(0, ALTAR_SIZE.y * 0.5, 0), stone)
	_box(root, Vector3(ALTAR_SIZE.x, 0.1, ALTAR_SIZE.z), Vector3(0, ALTAR_SIZE.y - 0.05, 0), stone)
	_box(root, Vector3(ALTAR_SIZE.x * 0.7, 0.02, ALTAR_SIZE.z + 0.06), Vector3(0, ALTAR_SIZE.y + 0.01, 0), _plain("cloth", Color(0.92, 0.9, 0.84)))
	_box(root, Vector3(0.3, 0.4, ALTAR_SIZE.z + 0.08), Vector3(0, ALTAR_SIZE.y - 0.18, 0), _plain("cloth_red", Color(0.55, 0.12, 0.12)))
	for x: float in [-0.65, 0.65]:
		_box(root, Vector3(0.08, 0.3, 0.08), Vector3(x, ALTAR_SIZE.y + 0.17, 0), _plain("wax", Color(0.95, 0.92, 0.82), 0.6))
		var flame := Effects.make_flame()
		flame.scale = Vector3.ONE * 0.35
		flame.position = Vector3(x, ALTAR_SIZE.y + 0.38, 0)
		root.add_child(flame)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.4)
	glow.light_energy = 0.8
	glow.omni_range = 4.0
	glow.position = Vector3(0, ALTAR_SIZE.y + 0.6, 0.3)
	root.add_child(glow)
	return root


## A pew `wide` metres long, its seat facing -z (the altar), its back rest behind.
static func pew(wide: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Pew"
	var wood := _wood()
	_box(root, Vector3(wide, 0.07, 0.42), Vector3(0, SEAT, -0.05), wood)
	_box(root, Vector3(wide, 0.5, 0.06), Vector3(0, SEAT + 0.3, PEW_DEPTH * 0.5 - 0.12), wood)
	for x: float in [-wide * 0.5 + 0.05, wide * 0.5 - 0.05]:
		_box(root, Vector3(0.07, BACK, PEW_DEPTH - 0.1), Vector3(x, BACK * 0.5, 0), wood)
	return root

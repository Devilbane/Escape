class_name WalkInFurniture
extends RefCounted
## The furniture of the village buildings one can walk into (see WalkIn), made of plain boxes at load
## time: a ladder up to the floor above and a table, shelf and stores in the villagers' houses, and the temple's pews, altar
## and flagstone floor. Their beds are CosyBeds.

## The altar: a block of pale stone (metres across, high, deep) with a cloth over it.
const ALTAR_SIZE := Vector3(1.9, 1.0, 0.9)
## A pew: how deep it is from its front to its back rest, and how far apart two rows stand.
const PEW_DEPTH := 0.7
const PEW_STEP := 1.45
const SEAT := 0.48
const BACK := 1.0
## The ladder: how far apart its rails stand, and how far in front of the hatch's edge.
const LADDER_WIDE := 0.5
const LADDER_BEFORE := 0.18

## How brightly a wall sconce's candle lights its room, and how far (metres).
const SCONCE_ENERGY := 1.6
const SCONCE_RANGE := 5.0
## On the modern renderer (Forward+) the same candle lit the room so faintly that nothing of it
## showed through the windows from outside: there it burns this much brighter.
const SCONCE_MODERN := 3.0

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


## The same grained wood, darker, for frames and rails.
static func _wood_dark() -> StandardMaterial3D:
	if not _mats.has("wood_dark"):
		var mat := (_wood().duplicate() as StandardMaterial3D)
		mat.albedo_color = Color(0.42, 0.3, 0.22)
		mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
		_mats["wood_dark"] = mat
	return _mats["wood_dark"]


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


## An upright wooden ladder up to the hatch of the floor above, `tall` metres from the floor to the
## hatch's edge, for the villagers to climb the way the hero climbs a built ladder (see LadderPose):
## its origin is on the floor under that edge, the climb goes along +x, the rails stand
## LADDER_BEFORE in front of the edge and a rung comes every LadderPose.RUNG from the floor up.
static func upright_ladder(tall: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Ladder"
	var x := -LADDER_BEFORE
	for z: float in [-LADDER_WIDE * 0.5, LADDER_WIDE * 0.5]:
		_box(root, Vector3(0.07, tall, 0.07), Vector3(x, tall * 0.5, z), _wood())
	var y := LadderPose.RUNG
	while y < tall - 0.05:
		_box(root, Vector3(0.05, 0.05, LADDER_WIDE), Vector3(x, y, 0), _wood())
		y += LadderPose.RUNG
	return root


## How thick a bedroom partition wall is (metres).
const PARTITION_THICK := 0.08


## A wall of vertical planks between two rooms, `length` metres long along +z from the origin and `high`
## metres high, standing on the floor in the middle of its thickness, with a doorway from `door_from`
## to `door_to` metres along it (2 m tall, a lintel over it), framed by posts and a rail along the top
## and a skirting board along the foot, so it reads as built, not as a box.
static func partition(length: float, high: float, door_from: float, door_to: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Partition"
	var wood := _wood()
	var dark := _wood_dark()
	var door_high := 2.0
	var t := PARTITION_THICK
	var plank := 0.16
	# The planks, each a hair apart so the joints show, a little different in length at the top.
	var z := 0.0
	var k := 0
	while z < length - 0.01:
		var w := minf(plank, length - z)
		var mid := z + w * 0.5
		var in_door := mid > door_from and mid < door_to
		var h := high - 0.05 if k % 3 == 0 else high
		if in_door:
			if h > door_high:
				_box(root, Vector3(t, h - door_high, w - 0.012), Vector3(0, door_high + (h - door_high) * 0.5, mid), wood)
		else:
			_box(root, Vector3(t, h, w - 0.012), Vector3(0, h * 0.5, mid), wood)
		z += plank
		k += 1
	# The frame: posts at the ends and beside the doorway, a lintel and a top rail, a skirting board.
	for pz: float in [0.03, door_from - 0.05, door_to + 0.05, length - 0.05]:
		_box(root, Vector3(t + 0.06, high, 0.1), Vector3(0, high * 0.5, pz), dark)
	_box(root, Vector3(t + 0.06, 0.12, door_to - door_from + 0.2), Vector3(0, door_high + 0.06, (door_from + door_to) * 0.5), dark)
	_box(root, Vector3(t + 0.05, 0.1, length), Vector3(0, high - 0.05, length * 0.5), dark)
	_box(root, Vector3(t + 0.05, 0.12, door_from), Vector3(0, 0.06, door_from * 0.5), dark)
	_box(root, Vector3(t + 0.05, 0.12, length - door_to), Vector3(0, 0.06, (door_to + length) * 0.5), dark)
	return root


## A woven rug, `size` metres (x across, y deep), lying flat on the floor: a warm red field with a
## border and two pale stripes, so a villager's room looks lived in.
static func rug(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Rug"
	_box(root, Vector3(size.x, 0.012, size.y), Vector3(0, 0.006, 0), _plain("rug_border", Color(0.36, 0.2, 0.12)))
	_box(root, Vector3(size.x - 0.16, 0.016, size.y - 0.16), Vector3(0, 0.008, 0), _plain("rug_field", Color(0.62, 0.2, 0.14)))
	for z: float in [-size.y * 0.22, size.y * 0.22]:
		_box(root, Vector3(size.x - 0.3, 0.02, 0.07), Vector3(0, 0.01, z), _plain("rug_stripe", Color(0.9, 0.74, 0.46)))
	return root


## A small shelf hung on a wall, its back to the wall (-z), with a lit candle in a brass dish and a
## jar on it: a warm spot of light in a villager's room.
static func candle_shelf() -> Node3D:
	var root := Node3D.new()
	root.name = "CandleShelf"
	var wood := _wood()
	_box(root, Vector3(0.7, 0.04, 0.24), Vector3(0, 0, 0.12), wood)
	_box(root, Vector3(0.04, 0.16, 0.18), Vector3(-0.28, -0.09, 0.09), wood)
	_box(root, Vector3(0.04, 0.16, 0.18), Vector3(0.28, -0.09, 0.09), wood)
	_cylinder(root, 0.09, 0.02, Vector3(0.12, 0.03, 0.12), _plain("brass", Color(0.78, 0.6, 0.3), 0.4))
	_cylinder(root, 0.035, 0.18, Vector3(0.12, 0.13, 0.12), _plain("wax", Color(0.95, 0.92, 0.82), 0.6))
	_cylinder(root, 0.07, 0.16, Vector3(-0.15, 0.1, 0.12), _plain("jar_green", Color(0.42, 0.55, 0.38), 0.5))
	var flame := Effects.make_flame()
	flame.scale = Vector3.ONE * 0.3
	flame.position = Vector3(0.12, 0.27, 0.12)
	root.add_child(flame)
	var glow := OmniLight3D.new()
	glow.name = "CandleGlow"
	glow.light_color = Color(1.0, 0.72, 0.42)
	glow.light_energy = 0.7
	glow.omni_range = 3.2
	glow.position = Vector3(0.12, 0.4, 0.35)
	# Walls all round it (see LightShadows.INDOOR), or it lit the ivy outside through the wall.
	glow.set_meta(LightShadows.INDOOR, true)
	glow.set_meta(LightShadows.WALL_CANDLE, true)
	root.add_child(glow)
	return root


## A wall sconce: an iron plate on the wall, an arm out of it and a candle in a brass cup on the arm,
## its back on the wall at the origin, facing +z. Its flame ("Flame", lit with emission) and its
## light ("SconceGlow") start out; WalkIn lights them at nightfall (see WalkIn.set_hour).
static func sconce() -> Node3D:
	var root := Node3D.new()
	root.name = "WallSconce"
	var iron := _plain("sconce_iron", Color(0.16, 0.15, 0.14), 0.55)
	_box(root, Vector3(0.12, 0.26, 0.02), Vector3(0, 0, 0.01), iron)
	_box(root, Vector3(0.03, 0.03, 0.2), Vector3(0, -0.06, 0.11), iron)
	_cylinder(root, 0.055, 0.03, Vector3(0, -0.035, 0.2), _plain("brass", Color(0.78, 0.6, 0.3), 0.4))
	_cylinder(root, 0.025, 0.14, Vector3(0, 0.05, 0.2), _plain("wax", Color(0.95, 0.92, 0.82), 0.6))
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var drop := SphereMesh.new()
	drop.radius = 0.018
	drop.height = 0.07
	flame.mesh = drop
	if not _mats.has("sconce_flame"):
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = Color(1.0, 0.78, 0.4)
		_mats["sconce_flame"] = hot
	flame.material_override = _mats["sconce_flame"]
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0, 0.155, 0.2)
	flame.visible = false
	root.add_child(flame)
	var glow := OmniLight3D.new()
	glow.name = "SconceGlow"
	glow.light_color = Color(1.0, 0.72, 0.42)
	glow.light_energy = SCONCE_ENERGY * (SCONCE_MODERN if Graphics.modern() else 1.0)
	glow.omni_range = SCONCE_RANGE
	glow.omni_attenuation = 1.6
	glow.position = Vector3(0, 0.2, 0.55)
	# Walls all round it: picked for its wall shadows before the lamps in the open (see
	# LightShadows.INDOOR), or its light fell through the house's walls onto the ivy and the snow.
	glow.set_meta(LightShadows.INDOOR, true)
	glow.set_meta(LightShadows.WALL_CANDLE, true)
	glow.visible = false
	root.add_child(glow)
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
	# The red band lies over the cloth, a little higher, so their tops never share a plane and flicker.
	_box(root, Vector3(0.3, 0.41, ALTAR_SIZE.z + 0.08), Vector3(0, ALTAR_SIZE.y - 0.175, 0), _plain("cloth_red", Color(0.55, 0.12, 0.12)))
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
	glow.set_meta(LightShadows.INDOOR, true)
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


# --- The halls' furniture (see VillageHalls) ---------------------------------------

static func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, turn := Basis()) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(turn, at)
	parent.add_child(mi)
	return mi


## A counter `wide` metres across, `high` and `deep`: a plank top over a panelled front (facing +z).
static func counter(wide: float, high: float, deep: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Counter"
	var wood := _wood()
	var dark := _plain("counter_wood", Color(0.5, 0.36, 0.24))
	_box(root, Vector3(wide, high - 0.06, deep - 0.08), Vector3(0, (high - 0.06) * 0.5, 0), dark)
	_box(root, Vector3(wide + 0.1, 0.06, deep + 0.06), Vector3(0, high - 0.03, 0), wood)
	var panels := maxi(1, int(wide / 0.8))
	for i in panels:
		var x := -wide * 0.5 + (i + 0.5) * wide / panels
		_box(root, Vector3(wide / panels - 0.12, high - 0.3, 0.03), Vector3(x, high * 0.5, deep * 0.5 - 0.03), wood)
	return root


## A round table, its top `radius` across, on one thick leg.
static func table(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Table"
	var wood := _wood()
	_cylinder(root, radius, 0.06, Vector3(0, 0.76, 0), wood)
	_cylinder(root, 0.07, 0.72, Vector3(0, 0.37, 0), wood)
	_cylinder(root, 0.3, 0.04, Vector3(0, 0.02, 0), wood)
	return root


## A three-legged stool.
static func stool() -> Node3D:
	var root := Node3D.new()
	root.name = "Stool"
	var wood := _wood()
	_cylinder(root, 0.19, 0.05, Vector3(0, 0.46, 0), wood)
	for i in 3:
		var a := TAU * i / 3.0
		_box(root, Vector3(0.04, 0.46, 0.04), Vector3(cos(a) * 0.12, 0.22, sin(a) * 0.12), wood)
	return root


## A tankard of ale.
static func mug() -> Node3D:
	var root := Node3D.new()
	root.name = "Mug"
	_cylinder(root, 0.055, 0.14, Vector3(0, 0.07, 0), _plain("pewter", Color(0.55, 0.55, 0.58), 0.4))
	_cylinder(root, 0.05, 0.01, Vector3(0, 0.14, 0), _plain("foam", Color(0.96, 0.93, 0.85)))
	_box(root, Vector3(0.02, 0.09, 0.05), Vector3(0.075, 0.07, 0), _plain("pewter", Color(0.55, 0.55, 0.58), 0.4))
	return root


## A barrel on its end, bound with iron hoops.
static func barrel() -> Node3D:
	var root := Node3D.new()
	root.name = "Barrel"
	_cylinder(root, 0.32, 0.9, Vector3(0, 0.45, 0), _wood())
	for y: float in [0.12, 0.45, 0.78]:
		_cylinder(root, 0.335, 0.05, Vector3(0, y, 0), _plain("iron", Color(0.22, 0.22, 0.24), 0.5))
	return root


## A crate `size` metres on a side.
static func crate(size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Crate"
	var wood := _wood()
	_box(root, Vector3.ONE * size, Vector3(0, size * 0.5, 0), _plain("crate", Color(0.55, 0.42, 0.28)))
	for y: float in [0.06, size - 0.06]:
		_box(root, Vector3(size + 0.02, 0.08, size + 0.02), Vector3(0, y, 0), wood)
	return root


## A sack of flour or grain, slumped.
static func sack() -> Node3D:
	var root := Node3D.new()
	root.name = "Sack"
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _plain("sackcloth", Color(0.78, 0.7, 0.55))
	mi.scale = Vector3(1.0, 1.15, 0.9)
	mi.position.y = 0.32
	root.add_child(mi)
	return root


## A sack of flour or grain from the mill: rough brown cloth, squat and full, tied at the top.
static func flour_sack() -> Node3D:
	var root := Node3D.new()
	root.name = "FlourSack"
	var cloth := _plain("millsack", Color(0.55, 0.45, 0.32))
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.27
	mesh.height = 0.62
	body.mesh = mesh
	body.material_override = cloth
	body.position.y = 0.31
	root.add_child(body)
	_cylinder(root, 0.07, 0.12, Vector3(0, 0.67, 0), cloth)
	_cylinder(root, 0.08, 0.03, Vector3(0, 0.64, 0), _plain("twine", Color(0.3, 0.22, 0.14)))
	return root


## A shelf `wide` x `high` and `deep`, its back on the wall (at -z); with `goods` its boards carry
## jars, bundles and loaves.
static func shelf(wide: float, high: float, deep: float, goods := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Shelf"
	var wood := _wood()
	for x: float in [-wide * 0.5 + 0.03, wide * 0.5 - 0.03]:
		_box(root, Vector3(0.06, high, deep), Vector3(x, high * 0.5, 0), wood)
	var boards := 4
	var colours := [Color(0.75, 0.5, 0.25), Color(0.45, 0.55, 0.35), Color(0.7, 0.62, 0.45), Color(0.6, 0.3, 0.25), Color(0.85, 0.8, 0.6)]
	for b in boards:
		var y := 0.15 + b * (high - 0.2) / (boards - 1)
		_box(root, Vector3(wide, 0.04, deep), Vector3(0, y, 0), wood)
		if not goods or b == boards - 1:
			continue
		var n := int(wide / 0.32)
		for i in n:
			if (i * 7 + b * 3) % 5 == 0:
				continue
			var x := -wide * 0.5 + 0.2 + i * (wide - 0.4) / maxf(1.0, n - 1)
			var c: Color = colours[(i + b * 2) % colours.size()]
			if (i + b) % 2 == 0:
				_cylinder(root, 0.08, 0.22, Vector3(x, y + 0.13, 0), _plain("jar%d" % ((i + b * 2) % colours.size()), c, 0.5))
			else:
				_box(root, Vector3(0.22, 0.18, deep * 0.7), Vector3(x, y + 0.11, 0), _plain("goods%d" % ((i + b * 2) % colours.size()), c))
	return root


## Pigeonholes for letters, `wide` x `high`, a few letters and rolls in them.
static func pigeonholes(wide: float, high: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Pigeonholes"
	var wood := _wood()
	var deep := 0.32
	var cols := maxi(2, int(wide / 0.35))
	var rows := maxi(2, int(high / 0.3))
	_box(root, Vector3(wide, high, 0.03), Vector3(0, high * 0.5, -deep * 0.5), _plain("dark_wood", Color(0.3, 0.2, 0.14)))
	for r in rows + 1:
		_box(root, Vector3(wide, 0.03, deep), Vector3(0, r * high / rows, 0), wood)
	for c in cols + 1:
		_box(root, Vector3(0.03, high, deep), Vector3(-wide * 0.5 + c * wide / cols, high * 0.5, 0), wood)
	# Letters standing in the holes: matte, dull parchment (a bright white glowed in the candlelight),
	# each with a dab of red wax, some leaning, a few lying in a pile.
	for r in rows:
		for c in cols:
			if (r * 5 + c * 3) % 4 == 0:
				continue
			var cell_w := wide / cols
			var at := Vector3(-wide * 0.5 + (c + 0.5) * cell_w, r * high / rows + 0.03, 0.0)
			if (r + c) % 3 == 0:
				for k in 2 + (r + c) % 2:
					var pile := envelope(cell_w * 0.62)
					pile.position = at + Vector3(0, 0.015 + k * 0.012, 0.02)
					pile.rotation = Vector3(-PI * 0.5, 0.25 * (k - 1), 0)
					root.add_child(pile)
			else:
				for k in 2:
					var standing := envelope(cell_w * 0.5)
					standing.position = at + Vector3((k - 0.5) * cell_w * 0.22, 0.0, 0.0)
					standing.rotation = Vector3(-0.12 - 0.1 * k, 0.15 * (k * 2 - 1), 0.12 * (k - 0.5))
					root.add_child(standing)
	return root


## A sealed letter, `wide` metres across, standing on its short edge: a dull parchment envelope
## with a flap line and a dab of red wax. Its origin is its bottom edge.
static func envelope(wide: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Letter"
	var high := wide * 0.7
	_box(root, Vector3(wide, high, 0.008), Vector3(0, high * 0.5, 0), _plain("letter", Color(0.7, 0.62, 0.45), 1.0))
	_box(root, Vector3(wide * 0.96, 0.006, 0.01), Vector3(0, high * 0.62, 0), _plain("letter_fold", Color(0.55, 0.47, 0.32), 1.0))
	_cylinder(root, wide * 0.09, 0.012, Vector3(0, high * 0.6, 0.007), _plain("wax", Color(0.55, 0.12, 0.1), 0.6), Basis(Vector3.RIGHT, PI * 0.5))
	return root


## A parcel in brown paper tied with string, `size` metres long. Stamped, it carries the post's
## red wax seal and a stamp mark; unstamped it is only tied and waits to be franked.
static func parcel(size: Vector3, stamped: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "StampedParcel" if stamped else "Parcel"
	var paper := _plain("parcel_paper", Color(0.58, 0.45, 0.3), 1.0)
	var twine := _plain("twine", Color(0.3, 0.22, 0.14))
	_box(root, size, Vector3(0, size.y * 0.5, 0), paper)
	# String once round each way and a knot on top.
	_box(root, Vector3(size.x + 0.012, size.y + 0.012, 0.015), Vector3(0, size.y * 0.5, 0), twine)
	_box(root, Vector3(0.015, size.y + 0.012, size.z + 0.012), Vector3(0, size.y * 0.5, 0), twine)
	_box(root, Vector3(0.05, 0.03, 0.05), Vector3(0, size.y + 0.01, 0), twine)
	if stamped:
		_cylinder(root, 0.045, 0.012, Vector3(0.08, size.y + 0.006, 0.08), _plain("wax", Color(0.55, 0.12, 0.1), 0.6))
		_box(root, Vector3(0.12, 0.006, 0.09), Vector3(-0.1, size.y + 0.004, -0.07), _plain("stamp_mark", Color(0.2, 0.25, 0.45), 1.0), Basis(Vector3.UP, 0.3))
	return root


## A sack of letters: a slumped cloth sack tied at the neck, envelopes sticking out of its mouth.
static func letter_sack() -> Node3D:
	var root := Node3D.new()
	root.name = "LetterSack"
	var cloth := _plain("letter_sack", Color(0.66, 0.58, 0.42), 1.0)
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.62
	body.mesh = mesh
	body.material_override = cloth
	body.scale = Vector3(1.0, 1.0, 0.9)
	body.position.y = 0.3
	root.add_child(body)
	_cylinder(root, 0.1, 0.14, Vector3(0, 0.62, 0), cloth)
	_cylinder(root, 0.115, 0.03, Vector3(0, 0.6, 0), _plain("twine", Color(0.3, 0.22, 0.14)))
	for i in 4:
		var letter := envelope(0.2)
		letter.position = Vector3((i - 1.5) * 0.04, 0.64, 0.0)
		letter.rotation = Vector3(0.0, i * 1.3, (i - 1.5) * 0.35)
		root.add_child(letter)
	return root


## A shop sign on an iron arm reaching `out` metres from the wall (along +z), the board hanging under
## it with the mark of the `kind` of hall: a mug for the tavern, a loaf for the shop, a horn for the post.
static func sign_board(kind: String, out: float) -> Node3D:
	var root := Node3D.new()
	var iron := _plain("iron", Color(0.22, 0.22, 0.24), 0.5)
	_box(root, Vector3(0.05, 0.05, out), Vector3(0, 0, out * 0.5), iron)
	_box(root, Vector3(0.04, 0.3, 0.04), Vector3(0, -0.15, 0.04), iron)
	var board := Node3D.new()
	board.position = Vector3(0, -0.36, out * 0.55)
	root.add_child(board)
	_box(board, Vector3(0.04, 0.5, 0.62), Vector3.ZERO, _plain("sign_board", Color(0.32, 0.22, 0.15)))
	for z: float in [-0.2, 0.2]:
		_box(board, Vector3(0.02, 0.12, 0.02), Vector3(0, 0.3, z), iron)
	var mark := _plain("sign_" + kind, {"tavern": Color(0.85, 0.65, 0.2), "shop": Color(0.9, 0.75, 0.45), "post": Color(0.95, 0.8, 0.25),
			"office": Color(0.93, 0.9, 0.8), "guild": Color(0.7, 0.2, 0.15), "mill": Color(0.92, 0.78, 0.35)}.get(kind, Color.WHITE), 0.5)
	for x: float in [-0.03, 0.03]:
		match kind:
			"tavern":
				_box(board, Vector3(0.02, 0.24, 0.16), Vector3(x, -0.02, -0.03), mark)
				_box(board, Vector3(0.02, 0.14, 0.04), Vector3(x, -0.02, 0.09), mark)
				_box(board, Vector3(0.02, 0.05, 0.18), Vector3(x, 0.12, -0.03), _plain("foam", Color(0.96, 0.93, 0.85)))
			"shop":
				_box(board, Vector3(0.02, 0.14, 0.36), Vector3(x, -0.04, 0), mark)
				_box(board, Vector3(0.02, 0.06, 0.26), Vector3(x, 0.06, 0), mark)
			"office":
				# A scroll with the Crown's blue seal.
				_box(board, Vector3(0.02, 0.26, 0.3), Vector3(x, 0.0, 0.0), mark)
				_box(board, Vector3(0.025, 0.08, 0.08), Vector3(x, -0.08, 0.08), _plain("seal", Color(0.25, 0.35, 0.8), 0.5))
			"guild":
				# A red shield with a pale axe across it.
				_box(board, Vector3(0.02, 0.26, 0.26), Vector3(x, 0.02, 0.0), mark)
				_box(board, Vector3(0.025, 0.3, 0.04), Vector3(x, 0.0, 0.0), _plain("axe_haft", Color(0.85, 0.8, 0.7)), Basis(Vector3.RIGHT, 0.6))
			"mill":
				# A golden sheaf of wheat: three stalks fanning out, bound in the middle.
				for tilt: float in [-0.35, 0.0, 0.35]:
					_box(board, Vector3(0.02, 0.3, 0.03), Vector3(x, 0.0, 0.0), mark, Basis(Vector3.RIGHT, tilt))
				_box(board, Vector3(0.025, 0.04, 0.1), Vector3(x, -0.02, 0.0), _plain("twine", Color(0.3, 0.22, 0.14)))
			_:
				_box(board, Vector3(0.02, 0.06, 0.3), Vector3(x, 0.0, 0.0), mark)
				_box(board, Vector3(0.02, 0.18, 0.08), Vector3(x, 0.02, 0.17), mark)
				_box(board, Vector3(0.02, 0.1, 0.06), Vector3(x, 0.0, -0.17), mark)
	return root


## A bookcase `wide` x `high` and `deep`, its back on the wall (at -z), full of ledgers and rolls.
static func bookcase(wide: float, high: float, deep: float) -> Node3D:
	var root := shelf(wide, high, deep)
	root.name = "Bookcase"
	var colours := [Color(0.45, 0.18, 0.15), Color(0.2, 0.28, 0.45), Color(0.35, 0.4, 0.25), Color(0.5, 0.38, 0.22), Color(0.9, 0.86, 0.74)]
	var boards := 4
	for b in boards - 1:
		var y := 0.15 + b * (high - 0.2) / (boards - 1)
		var x := -wide * 0.5 + 0.1
		var i := 0
		while x < wide * 0.5 - 0.12:
			var thick := 0.05 + float((i * 5 + b * 3) % 4) * 0.015
			var tall := 0.22 + float((i * 3 + b) % 3) * 0.03
			if (i + b * 2) % 9 != 4:
				var c: Color = colours[(i * 2 + b) % colours.size()]
				_box(root, Vector3(thick, tall, deep * 0.75), Vector3(x + thick * 0.5, y + 0.02 + tall * 0.5, 0), _plain("book%d" % ((i * 2 + b) % colours.size()), c))
			x += thick + 0.01
			i += 1
	return root


## A writing desk `wide` metres across: a counter at desk height with an open ledger, an inkpot and
## a stack of papers on it (its front, the side one stands before, at +z).
static func desk(wide: float, high: float, deep: float) -> Node3D:
	var root := counter(wide, high, deep)
	root.name = "Desk"
	var paper := _plain("paper", Color(0.93, 0.9, 0.8))
	_box(root, Vector3(0.5, 0.03, 0.36), Vector3(-0.15, high + 0.015, 0), paper, Basis(Vector3.UP, 0.12))
	_box(root, Vector3(0.02, 0.035, 0.34), Vector3(-0.15, high + 0.02, 0), _plain("book1", Color(0.2, 0.28, 0.45)), Basis(Vector3.UP, 0.12))
	_cylinder(root, 0.04, 0.07, Vector3(wide * 0.5 - 0.35, high + 0.035, -0.08), _plain("ink", Color(0.08, 0.08, 0.1), 0.3))
	_box(root, Vector3(0.008, 0.2, 0.008), Vector3(wide * 0.5 - 0.33, high + 0.13, -0.08), _plain("quill", Color(0.95, 0.95, 0.92)), Basis(Vector3.FORWARD, 0.35))
	for k in 3:
		_box(root, Vector3(0.3, 0.02, 0.22), Vector3(-wide * 0.5 + 0.35, high + 0.01 + k * 0.022, 0.02), paper, Basis(Vector3.UP, k * 0.08))
	return root


## A rack of weapons `wide` metres long against a wall (its back at -z): swords and axes on pegs.
static func weapon_rack(wide: float) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponRack"
	var wood := _wood()
	var iron := _plain("blade", Color(0.7, 0.72, 0.75), 0.35)
	for x: float in [-wide * 0.5 + 0.05, wide * 0.5 - 0.05]:
		_box(root, Vector3(0.08, 1.5, 0.3), Vector3(x, 0.75, 0), wood)
	for y: float in [0.3, 1.25]:
		_box(root, Vector3(wide, 0.06, 0.08), Vector3(0, y, -0.08), wood)
	var n := maxi(2, int(wide / 0.35))
	for i in n:
		var x := -wide * 0.5 + 0.25 + i * (wide - 0.5) / maxf(1.0, n - 1)
		if i % 2 == 0:
			_box(root, Vector3(0.05, 1.0, 0.02), Vector3(x, 0.85, 0.02), iron)
			_box(root, Vector3(0.2, 0.04, 0.04), Vector3(x, 0.4, 0.02), wood)
		else:
			_box(root, Vector3(0.04, 1.1, 0.04), Vector3(x, 0.7, 0.02), wood)
			_box(root, Vector3(0.2, 0.18, 0.02), Vector3(x + 0.08, 1.15, 0.02), iron)
	return root


## A pair of millstones on a timber frame under a wooden hopper, with the shaft rising from the
## runner stone up to the ceiling (to the sails above). The runner turns while the sails do
## (see Windmill): it is the child named "Runner".
static func millstones() -> Node3D:
	var root := Node3D.new()
	root.name = "Millstones"
	var wood := _wood()
	var stone := _plain("millstone", Color(0.42, 0.41, 0.39), 0.95)
	# The frame (a low box of planks) and the bed stone in it.
	_box(root, Vector3(1.7, 0.5, 1.7), Vector3(0, 0.25, 0), wood)
	_cylinder(root, 0.72, 0.18, Vector3(0, 0.59, 0), stone)
	var runner := Node3D.new()
	runner.name = "Runner"
	runner.position = Vector3(0, 0.68, 0)
	root.add_child(runner)
	_cylinder(runner, 0.7, 0.2, Vector3(0, 0.1, 0), stone)
	_cylinder(runner, 0.12, 0.04, Vector3(0, 0.21, 0), _plain("iron", Color(0.22, 0.22, 0.24), 0.5))
	_box(runner, Vector3(0.9, 0.06, 0.1), Vector3(0, 0.22, 0), wood)
	# The hopper on four legs over the stones, and the shaft up through it.
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.55, 0.55]:
			_box(root, Vector3(0.08, 0.8, 0.08), Vector3(x, 1.1, z), wood)
	_box(root, Vector3(0.9, 0.45, 0.9), Vector3(0, 1.65, 0), wood)
	_box(root, Vector3(0.55, 0.06, 0.55), Vector3(0, 1.42, 0), wood)
	_cylinder(root, 0.09, 2.6, Vector3(0, 2.3, 0), wood)
	return root


## A straw training dummy on a post, a sack for a head and a wooden shield strapped on.
static func dummy() -> Node3D:
	var root := Node3D.new()
	root.name = "Dummy"
	var wood := _wood()
	var straw := _plain("straw", Color(0.85, 0.72, 0.4))
	_box(root, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.042, 0), wood)
	_cylinder(root, 0.05, 1.5, Vector3(0, 0.75, 0), wood)
	_cylinder(root, 0.2, 0.6, Vector3(0, 1.15, 0), straw)
	_box(root, Vector3(0.9, 0.08, 0.08), Vector3(0, 1.3, 0), wood)
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = head
	mi.material_override = _plain("sackcloth", Color(0.78, 0.7, 0.55))
	mi.position = Vector3(0, 1.62, 0)
	root.add_child(mi)
	_cylinder(root, 0.22, 0.04, Vector3(-0.3, 1.1, 0.12), _plain("guild_red", Color(0.6, 0.2, 0.15)), Basis(Vector3.RIGHT, PI * 0.5))
	return root


## Widest a line of text on a poster may be, inside its 0.7 m paper.
const POSTER_TEXT_WIDTH := 0.6


## A notice on parchment hanging flat on a wall (at -z), 0.7 x 0.95 metres: a gold `title` over short
## `lines` of dark ink (German, translated by Lang). With no lines it shows the post's horn instead.
static func poster(title: String, lines: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Poster"
	_box(root, Vector3(0.7, 0.95, 0.015), Vector3(0, -0.475, 0.02), _plain("poster_paper", Color(0.7, 0.62, 0.45), 1.0))
	_box(root, Vector3(0.74, 0.03, 0.025), Vector3(0, 0.0, 0.025), _wood())
	_box(root, Vector3(0.74, 0.03, 0.025), Vector3(0, -0.95, 0.025), _wood())
	_poster_text(root, Lang.t(title), 0.15, Color(0.45, 0.1, 0.08), 0.16)
	if lines.is_empty():
		var gold := _plain("poster_gold", Color(0.75, 0.55, 0.15), 0.5)
		var bell := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.17
		cone.height = 0.4
		bell.mesh = cone
		bell.material_override = gold
		bell.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5 + 0.5), Vector3(0.05, -0.58, 0.04))
		root.add_child(bell)
		_cylinder(root, 0.05, 0.06, Vector3(-0.2, -0.7, 0.04), gold, Basis(Vector3.BACK, PI * 0.5 + 0.5))
	for i in lines.size():
		_poster_text(root, Lang.t(lines[i]), 0.3 + i * 0.16, Color(0.15, 0.1, 0.06), 0.11)
	return root


## Text on a poster, shrunk until it sits inside the paper: no taller than `height` metres and
## no wider than the paper, so it never spills onto the wall.
static func _poster_text(poster_root: Node3D, text: String, down: float, colour: Color, height: float) -> void:
	var font: Font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	var size := 48
	var pixel := height / float(size)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * pixel
	if width > POSTER_TEXT_WIDTH:
		pixel *= POSTER_TEXT_WIDTH / width
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = colour
	label.shaded = true
	label.position = Vector3(0, -down, 0.032)
	poster_root.add_child(label)


## What lies on a post office counter, built from boxes. Each is origin-on-the-surface.
## An ink pad with a stamp (a wooden handle on a rubber block) beside it.
static func stamp_and_ink() -> Node3D:
	var root := Node3D.new()
	root.name = "StampAndInk"
	_box(root, Vector3(0.14, 0.03, 0.1), Vector3(0, 0.015, 0), _plain("ink_tin", Color(0.2, 0.2, 0.24), 0.5))
	_box(root, Vector3(0.11, 0.008, 0.075), Vector3(0, 0.032, 0), _plain("ink", Color(0.45, 0.08, 0.1), 0.8))
	_box(root, Vector3(0.07, 0.015, 0.07), Vector3(0.2, 0.0075, 0.02), _plain("rubber", Color(0.15, 0.12, 0.1)))
	_cylinder(root, 0.02, 0.09, Vector3(0.2, 0.06, 0.02), _wood())
	return root


## A stick of red sealing wax with a brass seal and a candle stub.
static func wax_and_seal() -> Node3D:
	var root := Node3D.new()
	root.name = "WaxAndSeal"
	_box(root, Vector3(0.14, 0.02, 0.025), Vector3(0, 0.01, 0), _plain("wax", Color(0.55, 0.12, 0.1), 0.6), Basis(Vector3.UP, 0.4))
	var brass := _plain("brass", Color(0.7, 0.52, 0.2), 0.4)
	_cylinder(root, 0.03, 0.012, Vector3(0.14, 0.006, 0.04), brass)
	_cylinder(root, 0.012, 0.07, Vector3(0.14, 0.046, 0.04), brass)
	_cylinder(root, 0.025, 0.09, Vector3(-0.15, 0.045, -0.02), _plain("candle", Color(0.85, 0.8, 0.62)))
	return root


## A parcel scale: a wooden post and beam with a pan hanging at each end, a brass weight in one.
static func parcel_scale() -> Node3D:
	var root := Node3D.new()
	root.name = "ParcelScale"
	var brass := _plain("brass", Color(0.7, 0.52, 0.2), 0.4)
	_box(root, Vector3(0.14, 0.02, 0.1), Vector3(0, 0.01, 0), _wood())
	_box(root, Vector3(0.03, 0.34, 0.03), Vector3(0, 0.19, 0), _wood())
	_box(root, Vector3(0.5, 0.02, 0.02), Vector3(0, 0.36, 0), brass)
	for x: float in [-0.23, 0.23]:
		_box(root, Vector3(0.006, 0.18, 0.006), Vector3(x, 0.27, 0), brass)
		_cylinder(root, 0.09, 0.015, Vector3(x, 0.18, 0), brass)
	_cylinder(root, 0.03, 0.04, Vector3(0.23, 0.205, 0), _plain("weight", Color(0.3, 0.3, 0.32), 0.4))
	return root


## An open ledger with a quill standing in an inkwell.
static func ledger_and_quill() -> Node3D:
	var root := Node3D.new()
	root.name = "LedgerAndQuill"
	_box(root, Vector3(0.36, 0.03, 0.26), Vector3(0, 0.015, 0), _plain("ledger_cover", Color(0.3, 0.16, 0.1)))
	for x: float in [-0.085, 0.085]:
		_box(root, Vector3(0.16, 0.02, 0.23), Vector3(x, 0.04, 0), _plain("poster_paper", Color(0.7, 0.62, 0.45), 1.0))
	_cylinder(root, 0.025, 0.05, Vector3(0.3, 0.025, 0.02), _plain("ink_tin", Color(0.2, 0.2, 0.24), 0.5))
	_box(root, Vector3(0.012, 0.22, 0.012), Vector3(0.3, 0.13, 0.02), _plain("quill", Color(0.9, 0.88, 0.8)), Basis(Vector3.BACK, -0.25))
	return root


## A long cloth banner `high` metres long hanging flat on a wall (at -z), in `colour` with a pale band.
static func banner(colour: Color, high: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Banner"
	_box(root, Vector3(0.9, 0.05, 0.05), Vector3(0, 0, 0.03), _wood())
	_box(root, Vector3(0.7, high, 0.02), Vector3(0, -high * 0.5, 0.02), _plain("banner_%s" % colour.to_html(false), colour))
	_box(root, Vector3(0.7, 0.1, 0.025), Vector3(0, -high * 0.3, 0.025), _plain("banner_band", Color(0.92, 0.82, 0.5)))
	return root


# --- The tavern's furniture (see VillageHalls._tavern) ------------------------------

## A keg lying on a wooden cradle, bound with iron hoops, its brass tap on the front face (+z).
## The origin is on the floor (or the counter) under its middle.
static func keg() -> Node3D:
	var root := Node3D.new()
	root.name = "Keg"
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	_cylinder(root, 0.24, 0.56, Vector3(0, 0.34, 0), _wood(), along)
	for z: float in [-0.19, 0.0, 0.19]:
		_cylinder(root, 0.248, 0.04, Vector3(0, 0.34, z), _plain("iron", Color(0.22, 0.22, 0.24), 0.5), along)
	for z: float in [-0.17, 0.17]:
		_box(root, Vector3(0.5, 0.1, 0.05), Vector3(0, 0.05, z), _wood())
	var brass := _plain("brass", Color(0.78, 0.6, 0.3), 0.4)
	_cylinder(root, 0.025, 0.12, Vector3(0, 0.27, 0.34), brass, along)
	_box(root, Vector3(0.025, 0.07, 0.025), Vector3(0, 0.33, 0.37), brass)
	return root


## A beer tap on the bar: a brass column with a lever on top and a spout over the drip tray.
static func beer_tap() -> Node3D:
	var root := Node3D.new()
	root.name = "BeerTap"
	var brass := _plain("brass", Color(0.78, 0.6, 0.3), 0.4)
	_cylinder(root, 0.03, 0.3, Vector3(0, 0.15, 0), brass)
	_cylinder(root, 0.045, 0.04, Vector3(0, 0.02, 0), brass)
	_box(root, Vector3(0.02, 0.09, 0.02), Vector3(0, 0.34, 0.03), _plain("tap_grip", Color(0.3, 0.2, 0.12)), Basis(Vector3.RIGHT, -0.4))
	_box(root, Vector3(0.025, 0.025, 0.09), Vector3(0, 0.26, 0.06), brass)
	return root


## A drip tray with a grid, to stand under the taps.
static func drip_tray(wide: float) -> Node3D:
	var root := Node3D.new()
	root.name = "DripTray"
	_box(root, Vector3(wide, 0.025, 0.16), Vector3(0, 0.0125, 0), _plain("iron", Color(0.22, 0.22, 0.24), 0.5))
	return root


## A high-backed wooden chair with arms, facing +z: Fritz's seat. Its seat is SEAT_HIGH off the floor.
static func chair() -> Node3D:
	var root := Node3D.new()
	root.name = "Chair"
	var wood := _wood()
	_box(root, Vector3(0.5, 0.05, 0.5), Vector3(0, 0.46, 0), wood)
	for x: float in [-0.22, 0.22]:
		for z: float in [-0.22, 0.22]:
			_box(root, Vector3(0.05, 0.46, 0.05), Vector3(x, 0.23, z), wood)
		_box(root, Vector3(0.05, 0.05, 0.46), Vector3(x, 0.72, 0), wood)
		_box(root, Vector3(0.05, 0.26, 0.05), Vector3(x, 0.59, 0.2), wood)
	_box(root, Vector3(0.5, 0.5, 0.05), Vector3(0, 0.75, -0.24), wood)
	return root


## A plank bench `wide` metres long, facing +z.
static func bench(wide: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bench"
	var wood := _wood()
	_box(root, Vector3(wide, 0.05, 0.3), Vector3(0, 0.46, 0), wood)
	for x: float in [-wide * 0.5 + 0.2, wide * 0.5 - 0.2]:
		_box(root, Vector3(0.06, 0.44, 0.26), Vector3(x, 0.22, 0), wood)
	return root


## A rail on the wall (back on the wall at -z) with `count` tankards hanging side by side on pegs.
static func mug_rail(wide: float, count: int) -> Node3D:
	var root := Node3D.new()
	root.name = "MugRail"
	_box(root, Vector3(wide, 0.08, 0.03), Vector3(0, 0, 0.015), _wood())
	for i in count:
		var mug := mug()
		mug.scale = Vector3.ONE * 1.1
		mug.position = Vector3(-wide * 0.5 + (i + 0.5) * wide / count, -0.17, 0.08)
		root.add_child(mug)
		_box(root, Vector3(0.02, 0.02, 0.08), Vector3(mug.position.x, -0.02, 0.07), _plain("iron", Color(0.22, 0.22, 0.24), 0.5))
	return root


## A stub of candle in a dish for a table, its flame lit with emission and no light of its own.
static func table_candle() -> Node3D:
	var root := Node3D.new()
	root.name = "TableCandle"
	_cylinder(root, 0.05, 0.015, Vector3(0, 0.008, 0), _plain("brass", Color(0.78, 0.6, 0.3), 0.4))
	_cylinder(root, 0.022, 0.07, Vector3(0, 0.05, 0), _plain("wax", Color(0.95, 0.92, 0.82), 0.6))
	var flame := MeshInstance3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.014
	drop.height = 0.055
	flame.mesh = drop
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.78, 0.4)
	flame.material_override = hot
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0, 0.115, 0)
	root.add_child(flame)
	return root


## A stone hearth `wide` metres across against a wall (back at -z, open to +z): a fire burning on
## logs under a mantel, a chimney breast above it, and a warm light ("HearthGlow") that WalkIn
## shows while the hero is inside. A fire, no electricity: the tavern's own warmth.
static func hearth(wide: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Hearth"
	var stone := _plain("hearth_stone", Color(0.46, 0.43, 0.4), 0.95)
	var soot := _plain("hearth_soot", Color(0.07, 0.06, 0.06), 1.0)
	var deep := 0.55
	var high := 1.2
	var mouth := wide * 0.58
	for x: float in [-(wide + mouth) * 0.25, (wide + mouth) * 0.25]:
		_box(root, Vector3((wide - mouth) * 0.5, high, deep), Vector3(x, high * 0.5, deep * 0.5), stone)
	_box(root, Vector3(mouth, high - 0.75, deep), Vector3(0, 0.75 + (high - 0.75) * 0.5, deep * 0.5), stone)
	_box(root, Vector3(mouth, 0.75, 0.04), Vector3(0, 0.375, 0.03), soot)
	_box(root, Vector3(wide + 0.1, 0.06, deep + 0.1), Vector3(0, high + 0.03, deep * 0.5 + 0.03), _wood())
	_box(root, Vector3(wide * 0.6, 1.4, 0.34), Vector3(0, high + 0.06 + 0.7, 0.17), stone)
	_box(root, Vector3(wide, 0.05, deep + 0.2), Vector3(0, 0.025, deep * 0.5 + 0.1), stone)
	var log := _plain("hearth_log", Color(0.3, 0.2, 0.12))
	_cylinder(root, 0.07, mouth * 0.8, Vector3(0, 0.12, 0.2), log, Basis(Vector3.BACK, PI * 0.5))
	_cylinder(root, 0.06, mouth * 0.7, Vector3(0, 0.2, 0.3), log, Basis(Vector3.BACK, PI * 0.5))
	var flame := Effects.make_flame()
	flame.name = "HearthFlame"
	flame.scale = Vector3.ONE * 1.3
	flame.position = Vector3(0, 0.3, 0.25)
	root.add_child(flame)
	var glow := OmniLight3D.new()
	glow.name = "HearthGlow"
	glow.light_color = Color(1.0, 0.62, 0.3)
	glow.light_energy = 1.2
	glow.omni_range = 6.0
	glow.omni_attenuation = 1.4
	glow.position = Vector3(0, 0.6, 0.8)
	glow.set_meta(LightShadows.INDOOR, true)
	root.add_child(glow)
	return root

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
	var paper := _plain("paper", Color(0.93, 0.9, 0.8))
	for r in rows:
		for c in cols:
			if (r * 5 + c * 3) % 4 == 0:
				continue
			var at := Vector3(-wide * 0.5 + (c + 0.5) * wide / cols, r * high / rows + 0.06, 0.02)
			_box(root, Vector3(wide / cols * 0.6, 0.08, deep * 0.6), at, paper)
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
			"office": Color(0.93, 0.9, 0.8), "guild": Color(0.7, 0.2, 0.15)}.get(kind, Color.WHITE), 0.5)
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


## A straw training dummy on a post, a sack for a head and a wooden shield strapped on.
static func dummy() -> Node3D:
	var root := Node3D.new()
	root.name = "Dummy"
	var wood := _wood()
	var straw := _plain("straw", Color(0.85, 0.72, 0.4))
	_box(root, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), wood)
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


## A long cloth banner `high` metres long hanging flat on a wall (at -z), in `colour` with a pale band.
static func banner(colour: Color, high: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Banner"
	_box(root, Vector3(0.9, 0.05, 0.05), Vector3(0, 0, 0.03), _wood())
	_box(root, Vector3(0.7, high, 0.02), Vector3(0, -high * 0.5, 0.02), _plain("banner_%s" % colour.to_html(false), colour))
	_box(root, Vector3(0.7, 0.1, 0.025), Vector3(0, -high * 0.3, 0.025), _plain("banner_band", Color(0.92, 0.82, 0.5)))
	return root

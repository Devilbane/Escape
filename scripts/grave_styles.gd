class_name GraveStyles
extends RefCounted
## The kinds of gravestones of the graveyard, beyond the kit's six models: stone crosses (plain and Celtic),
## obelisks, angels, urn pillars, family tombs, flat ledger stones, broken stones and stones that have sunk
## and leant over. Each is built from a few carved pieces (plinths, shafts, mouldings, a recessed panel with
## lines of lettering, wings and robes) in the village's old stone (AgedStone.memorial_material: lichen and
## moss, no plain colour), most with a mound of earth, and some with flowers, a candle stub or pebbles at the
## foot. Every stone is picked from its tile (see pick), so it never changes.
##
## `build(style, seed)` returns the stone with its foot at the origin, its face towards +z, and
## `footprint(style)` the box it blocks (width, height, depth, metres). Tested by tests/grave_styles.gd.

## The styles with how often each is picked (the kit's own models are "classic").
const WEIGHTS := {"classic": 30, "cross": 10, "celtic": 6, "obelisk": 6, "angel": 6, "urn": 6, "tomb": 6,
	"ledger": 8, "broken": 8, "sunken": 8}
## What each blocks: width, height, depth.
const FOOTPRINT := {
	"classic": Vector3(2.0, 1.6, 1.0), "cross": Vector3(1.2, 1.9, 0.8), "celtic": Vector3(1.3, 2.0, 0.8),
	"obelisk": Vector3(1.1, 2.6, 1.1), "angel": Vector3(1.1, 2.2, 1.0), "urn": Vector3(1.0, 1.9, 1.0),
	"tomb": Vector3(2.4, 1.0, 1.4), "ledger": Vector3(1.8, 0.5, 1.0), "broken": Vector3(1.1, 0.9, 0.8),
	"sunken": Vector3(1.0, 1.3, 0.6)}
## The stones in the order of the table, and the tints of the stone: grey granite, pale marble, dark slate,
## weathered sandstone.
const TINTS := [Color(0.60, 0.61, 0.60), Color(0.80, 0.80, 0.77), Color(0.42, 0.44, 0.47), Color(0.70, 0.64, 0.55)]
const EARTH := Color(0.27, 0.19, 0.12)
const FLOWERS := [Color(0.85, 0.82, 0.9), Color(0.9, 0.75, 0.2), Color(0.75, 0.2, 0.25), Color(0.45, 0.4, 0.8)]
static var _earth_material: StandardMaterial3D


## The style of the stone on a tile: stable for a tile and a map, spread by WEIGHTS.
static func pick(map_name: String, c: Vector2i) -> String:
	var total := 0
	for style: String in WEIGHTS:
		total += int(WEIGHTS[style])
	var roll := absi(hash("%s|stein|%s" % [map_name, c])) % total
	for style: String in WEIGHTS:
		roll -= int(WEIGHTS[style])
		if roll < 0:
			return style
	return "classic"


static func footprint(style: String) -> Vector3:
	return FOOTPRINT.get(style, FOOTPRINT.classic)


## A carved stone of `style`; `seed` sets its tint, moss, lean and what lies at its foot.
static func build(style: String, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Node3D.new()
	root.name = "Grabmal_" + style
	var tint: Color = TINTS[rng.randi() % TINTS.size()]
	if style == "angel":
		tint = TINTS[1]
	var stone := AgedStone.memorial_material(tint, rng.randf_range(0.6, 1.5), 0.35)
	var dark := AgedStone.memorial_material(tint * 0.55, 1.0, 0.2)
	match style:
		"cross":
			_cross(root, stone, dark, false)
		"celtic":
			_cross(root, stone, dark, true)
		"obelisk":
			_obelisk(root, stone)
		"angel":
			_angel(root, stone)
		"urn":
			_urn(root, stone, dark)
		"tomb":
			_tomb(root, stone, dark, rng)
		"ledger":
			_ledger(root, stone, dark)
		"broken":
			_broken(root, stone, dark, rng)
		"sunken":
			_sunken(root, stone, dark, rng)
	if style != "tomb" and style != "ledger":
		_mound(root, rng)
	_offerings(root, rng, style)
	return root


# --- Pieces -----------------------------------------------------------------------------------

static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, mat: Material, sides := 16, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	cyl.radial_segments = sides
	cyl.rings = 1
	m.mesh = cyl
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


static func _ball(parent: Node3D, radius: float, scale: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	m.mesh = sphere
	m.material_override = mat
	m.position = at
	m.scale = scale
	parent.add_child(m)
	return m


## A step-moulded base: two slabs, the upper set in a little.
static func _plinth(parent: Node3D, width: float, depth: float, mat: Material, height := 0.3) -> float:
	_box(parent, Vector3(width, height * 0.55, depth), Vector3(0, height * 0.275, 0), mat)
	_box(parent, Vector3(width * 0.86, height * 0.45, depth * 0.82), Vector3(0, height * 0.55 + height * 0.225, 0), mat)
	return height


## A recessed panel on a face with lines of lettering cut into it.
static func _panel(parent: Node3D, size: Vector2, at: Vector3, dark: Material, lines := 3) -> void:
	_box(parent, Vector3(size.x, size.y, 0.03), at, dark)
	for i in lines:
		var w := size.x * (0.78 if i % 2 == 0 else 0.55)
		_box(parent, Vector3(w, 0.022, 0.034), at + Vector3(0, size.y * 0.3 - i * size.y * 0.3 / maxf(1.0, lines - 1.0) * 1.8, 0.012), AgedStone.memorial_material(Color(0.2, 0.2, 0.2), 0.0, 0.0))


static func _cross(root: Node3D, stone: Material, dark: Material, celtic: bool) -> void:
	var base := _plinth(root, 1.1, 0.7, stone, 0.34)
	_box(root, Vector3(0.62, 0.34, 0.34), Vector3(0, base + 0.17, 0), stone)
	var shaft := 1.15
	_box(root, Vector3(0.26, shaft, 0.2), Vector3(0, base + 0.34 + shaft * 0.5, 0), stone)
	var arm_y := base + 0.34 + shaft * 0.72
	_box(root, Vector3(0.86, 0.24, 0.2), Vector3(0, arm_y, 0), stone)
	# Chamfered ends and a small cap.
	_box(root, Vector3(0.3, 0.12, 0.24), Vector3(0, base + 0.34 + shaft + 0.04, 0), stone)
	if celtic:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.2
		torus.outer_radius = 0.32
		torus.rings = 20
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = stone
		ring.position = Vector3(0, arm_y, 0)
		ring.rotation.x = PI / 2.0
		ring.scale = Vector3(1.0, 1.0, 0.7)
		root.add_child(ring)
	_panel(root, Vector2(0.5, 0.26), Vector3(0, base * 0.6 + 0.17, 0.18), dark, 2)


static func _obelisk(root: Node3D, stone: Material) -> void:
	var y := 0.0
	for step: Vector2 in [Vector2(1.0, 0.22), Vector2(0.82, 0.22), Vector2(0.66, 0.34)]:
		_box(root, Vector3(step.x, step.y, step.x), Vector3(0, y + step.y * 0.5, 0), stone)
		y += step.y
	_cylinder(root, 0.12, 0.27, 1.55, Vector3(0, y + 0.775, 0), stone, 4, Vector3(0, PI / 4.0, 0))
	_cylinder(root, 0.0, 0.12, 0.26, Vector3(0, y + 1.55 + 0.13, 0), stone, 4, Vector3(0, PI / 4.0, 0))
	# A carved band under the tip.
	_cylinder(root, 0.145, 0.15, 0.05, Vector3(0, y + 1.38, 0), stone, 4, Vector3(0, PI / 4.0, 0))


static func _angel(root: Node3D, stone: Material) -> void:
	var base := _plinth(root, 1.0, 0.85, stone, 0.42)
	_box(root, Vector3(0.7, 0.35, 0.55), Vector3(0, base + 0.175, 0), stone)
	var y := base + 0.35
	# A long robe falling to the plinth, a belt, shoulders, head and a halo.
	_cylinder(root, 0.17, 0.36, 0.95, Vector3(0, y + 0.475, 0), stone, 14)
	_cylinder(root, 0.19, 0.19, 0.05, Vector3(0, y + 0.82, 0), stone, 14)
	_ball(root, 0.2, Vector3(1.25, 0.55, 0.8), Vector3(0, y + 0.98, 0), stone)
	_ball(root, 0.15, Vector3.ONE, Vector3(0, y + 1.16, 0.01), stone)
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.2
	halo.mesh = ring
	halo.material_override = stone
	halo.position = Vector3(0, y + 1.38, -0.02)
	halo.rotation.x = 0.25
	root.add_child(halo)
	# Arms folded over the chest, and two wings swept up behind the shoulders.
	_box(root, Vector3(0.34, 0.1, 0.12), Vector3(0, y + 0.8, 0.17), stone, Vector3(0, 0, 0.12))
	for side: float in [-1.0, 1.0]:
		var wing := _ball(root, 0.5, Vector3(0.32, 1.0, 0.11), Vector3(side * 0.3, y + 1.05, -0.17), stone)
		wing.rotation = Vector3(0.2, 0.0, -side * 0.45)
		for i in 3:
			var feather := _ball(root, 0.34, Vector3(0.22, 1.0, 0.09), Vector3(side * (0.42 + i * 0.07), y + 0.82 - i * 0.07, -0.19 - i * 0.01), stone)
			feather.rotation = Vector3(0.2, 0.0, -side * (0.55 + i * 0.16))


static func _urn(root: Node3D, stone: Material, dark: Material) -> void:
	var base := _plinth(root, 1.0, 0.8, stone, 0.38)
	_box(root, Vector3(0.62, 0.7, 0.5), Vector3(0, base + 0.35, 0), stone)
	_box(root, Vector3(0.74, 0.12, 0.6), Vector3(0, base + 0.76, 0), stone)
	_panel(root, Vector2(0.42, 0.4), Vector3(0, base + 0.36, 0.26), dark, 3)
	var y := base + 0.82
	_cylinder(root, 0.14, 0.2, 0.1, Vector3(0, y + 0.05, 0), stone)
	_ball(root, 0.3, Vector3(1.0, 1.15, 1.0), Vector3(0, y + 0.34, 0), stone)
	_cylinder(root, 0.2, 0.13, 0.12, Vector3(0, y + 0.66, 0), stone)
	# A drape of cloth carved over the urn.
	_ball(root, 0.2, Vector3(1.6, 0.35, 1.0), Vector3(0, y + 0.76, 0), stone)


static func _tomb(root: Node3D, stone: Material, dark: Material, rng: RandomNumberGenerator) -> void:
	_box(root, Vector3(2.3, 0.28, 1.35), Vector3(0, 0.14, 0), stone)
	_box(root, Vector3(2.0, 0.55, 1.05), Vector3(0, 0.28 + 0.275, 0), stone)
	# A heavy lid, a little askew from the years, with a moulded edge.
	var lid := _box(root, Vector3(2.18, 0.16, 1.22), Vector3(0, 0.83 + 0.08, 0), stone, Vector3(0, rng.randf_range(-0.03, 0.03), 0))
	_box(lid, Vector3(1.9, 0.1, 0.9), Vector3(0, 0.12, 0), stone)
	# Carved panels on the front and a headstone at one end.
	_panel(root, Vector2(0.8, 0.34), Vector3(-0.45, 0.56, 0.54), dark, 3)
	_panel(root, Vector2(0.5, 0.34), Vector3(0.5, 0.56, 0.54), dark, 2)
	_box(root, Vector3(0.4, 0.85, 0.16), Vector3(-0.92, 1.0, -0.38), stone)
	_ball(root, 0.2, Vector3(1.0, 0.6, 0.4), Vector3(-0.92, 1.45, -0.38), stone)


static func _ledger(root: Node3D, stone: Material, dark: Material) -> void:
	_box(root, Vector3(1.6, 0.16, 0.9), Vector3(0, 0.08, 0), stone)
	_box(root, Vector3(1.35, 0.05, 0.68), Vector3(0, 0.185, 0), dark)
	for i in 3:
		_box(root, Vector3(1.0 - 0.25 * (i % 2), 0.02, 0.05), Vector3(0, 0.215, -0.16 + i * 0.16), stone)
	# A headstone at its head.
	_box(root, Vector3(0.7, 0.4, 0.12), Vector3(0, 0.25, -0.5), stone)
	_ball(root, 0.35, Vector3(1.0, 0.45, 0.35), Vector3(0, 0.45, -0.5), stone)


static func _broken(root: Node3D, stone: Material, dark: Material, rng: RandomNumberGenerator) -> void:
	_box(root, Vector3(0.95, 0.2, 0.34), Vector3(0, 0.1, 0), stone)
	# The stump with a jagged top.
	_box(root, Vector3(0.84, 0.46, 0.22), Vector3(0, 0.43, 0), stone)
	_box(root, Vector3(0.4, 0.14, 0.22), Vector3(-0.1, 0.7, 0), stone, Vector3(0, 0, 0.3))
	_panel(root, Vector2(0.5, 0.26), Vector3(0, 0.45, 0.12), dark, 2)
	# The top piece, fallen in front, and a few chips.
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	_box(root, Vector3(0.6, 0.36, 0.2), Vector3(side * 0.3, 0.14, 0.55), stone, Vector3(0.12, rng.randf_range(0.3, 1.0), 1.35))
	for i in 3:
		_box(root, Vector3(0.12, 0.08, 0.1), Vector3(rng.randf_range(-0.6, 0.6), 0.04, rng.randf_range(0.2, 0.9)), stone, Vector3(0, rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))


static func _sunken(root: Node3D, stone: Material, dark: Material, rng: RandomNumberGenerator) -> void:
	var tilt := Node3D.new()
	tilt.position = Vector3(0, -0.22, 0)
	tilt.rotation = Vector3(rng.randf_range(-0.12, -0.04), 0.0, rng.randf_range(-0.22, 0.22))
	root.add_child(tilt)
	_box(tilt, Vector3(0.82, 1.1, 0.2), Vector3(0, 0.62, 0), stone)
	_ball(tilt, 0.41, Vector3(1.0, 0.62, 0.5), Vector3(0, 1.17, 0), stone)
	_panel(tilt, Vector2(0.52, 0.5), Vector3(0, 0.78, 0.11), dark, 3)
	# Earth heaped about its foot where it has sunk.
	_ball(root, 0.8, Vector3(1.0, 0.18, 0.5), Vector3(0, 0.0, 0.15), stone)


static func _earth() -> StandardMaterial3D:
	if _earth_material != null:
		return _earth_material
	var noise := FastNoiseLite.new()
	noise.seed = 17
	noise.frequency = 0.08
	var fine := FastNoiseLite.new()
	fine.seed = 4
	fine.frequency = 0.5
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var v := 0.62 + noise.get_noise_2d(x, y) * 0.3 + fine.get_noise_2d(x, y) * 0.16
			var grass := clampf(noise.get_noise_2d(x * 1.7 + 50, y * 1.7) * 2.0, 0.0, 0.7)
			img.set_pixel(x, y, EARTH.lerp(Color(0.24, 0.32, 0.14), grass) * v)
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
	_earth_material = mat
	return mat


## A low mound of earth, grassed in patches, in front of the stone.
static func _mound(root: Node3D, rng: RandomNumberGenerator) -> void:
	var mound := _ball(root, 0.75, Vector3(1.05, 0.2, 1.1 + rng.randf() * 0.4), Vector3(0, 0.0, 0.85), _earth())
	mound.rotation.y = rng.randf_range(-0.1, 0.1)


## Flowers, a candle stub or pebbles left at the foot.
static func _offerings(root: Node3D, rng: RandomNumberGenerator, style: String) -> void:
	var z := 0.95 if style != "tomb" else 1.1
	var roll := rng.randf()
	if roll < 0.35:
		var colour: Color = FLOWERS[rng.randi() % FLOWERS.size()]
		var petal := StandardMaterial3D.new()
		petal.albedo_color = colour
		petal.roughness = 0.8
		var green := StandardMaterial3D.new()
		green.albedo_color = Color(0.2, 0.34, 0.14)
		green.roughness = 1.0
		var x := rng.randf_range(-0.4, 0.4)
		for i in 5:
			var at := Vector3(x + rng.randf_range(-0.16, 0.16), 0.0, z + rng.randf_range(-0.12, 0.12))
			_cylinder(root, 0.008, 0.012, 0.22, at + Vector3(0, 0.12, 0), green, 5)
			_ball(root, 0.05, Vector3(1.0, 0.7, 1.0), at + Vector3(0, 0.25, 0), petal)
	elif roll < 0.55:
		var wax := StandardMaterial3D.new()
		wax.albedo_color = Color(0.9, 0.86, 0.72)
		wax.roughness = 0.6
		var flame := StandardMaterial3D.new()
		flame.albedo_color = Color(1.0, 0.8, 0.4)
		flame.emission_enabled = true
		flame.emission = Color(1.0, 0.62, 0.2)
		flame.emission_energy_multiplier = 1.6
		var at := Vector3(rng.randf_range(-0.35, 0.35), 0.0, z)
		_cylinder(root, 0.035, 0.04, 0.14, at + Vector3(0, 0.07, 0), wax, 8)
		_ball(root, 0.022, Vector3(1.0, 1.7, 1.0), at + Vector3(0, 0.17, 0), flame)
	elif roll < 0.7:
		var pebble := AgedStone.memorial_material(TINTS[0], 0.4, 0.3)
		for i in 4:
			_ball(root, 0.07, Vector3(1.0, 0.6, 1.0), Vector3(rng.randf_range(-0.5, 0.5), 0.02, z + rng.randf_range(-0.15, 0.2)), pebble)

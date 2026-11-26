class_name NohpaanParts
extends RefCounted
## The things of Nohpaan that are built from shapes (see Nohpaan, which places them on the map letters): cedars,
## rhododendron, the limewashed monastery wall with its red-tiled cap, the gate tower, stupas, prayer wheels, the
## lotus pond, flagstones and the sealed gates. Every surface carries a texture (see NohpaanSurface).

const TILE := 4.0


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	node.scale = scale
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _box(parent: Node3D, size: Vector3, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, mat, pos, rot)


static func _cyl(parent: Node3D, top: float, bottom: float, height: float, mat: Material, pos := Vector3.ZERO, segments := 12, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _mesh(parent, mesh, mat, pos, rot)


static func _ball(parent: Node3D, radius: float, mat: Material, pos := Vector3.ZERO, scale := Vector3.ONE, segments := 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	return _mesh(parent, mesh, mat, pos, Vector3.ZERO, scale)


static func _lamp(parent: Node3D, colour: Color, energy: float, reach: float, pos: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.position = pos
	parent.add_child(light)
	return light


static func _holder(level: Level, c: Vector2i, name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = "%s_%d_%d" % [name, c.x, c.y]
	level.add_child(holder)
	holder.position = level.cell_to_world(c)
	return holder


# --- Trees and bushes ----------------------------------------------------------------------------------

## A mountain cedar: a ridged trunk and six drooping tiers of needles, each wider than the one above. A little
## different on every tile.
static func cedar(level: Level, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + 77
	var holder := _holder(level, c, "Cedar")
	holder.position += Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
	holder.rotation.y = rng.randf() * TAU
	var size := rng.randf_range(0.9, 1.35)
	var bark := NohpaanSurface.material("bark", Color.WHITE, 0.95, 2.0)
	var tiers := 6
	_cyl(holder, 0.28 * size, 0.55 * size, 3.2 * size, bark, Vector3(0, 1.6 * size, 0), 9)
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf()
		_cyl(holder, 0.04, 0.12, 1.1 * size, bark, Vector3(cos(a) * 0.5, 1.3 * size, sin(a) * 0.5), 6, Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9))
	for i in tiers:
		var t := float(i) / tiers
		var radius := lerpf(2.7, 0.7, t) * size
		var y := lerpf(2.2, 7.0, t) * size
		var tint := Color(0.85, 1.0, 0.9).lerp(Color(1.05, 1.1, 0.9), t) * rng.randf_range(0.9, 1.08)
		var foliage := NohpaanSurface.material("needles", tint, 0.9, 3.0)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = radius
		mesh.height = 2.0 * size
		mesh.radial_segments = 12
		mesh.rings = 1
		_mesh(holder, mesh, foliage, Vector3(0, y, 0), Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05)))
		# The droop: a skirt of shorter needles hanging from the rim.
		var skirt := CylinderMesh.new()
		skirt.top_radius = radius * 0.96
		skirt.bottom_radius = radius * 0.8
		skirt.height = 0.45 * size
		skirt.radial_segments = 12
		skirt.rings = 1
		_mesh(holder, skirt, foliage, Vector3(0, y - 0.9 * size, 0))
	level._add_solid(holder.position, Vector3(1.2, 4.0, 1.2))
	level._near_walls.add(holder)


## A rhododendron: three domes of leathery leaves, covered in crimson, pink and white blossom.
static func rhododendron(level: Level, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + 31
	var holder := _holder(level, c, "Rhododendron")
	holder.position += Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	var leaf := NohpaanSurface.material("leaf", Color(0.8, 1.0, 0.85), 0.8, 2.0)
	var colours := [Color(0.9, 0.18, 0.32), Color(0.98, 0.55, 0.7), Color(0.98, 0.93, 0.95), Color(0.85, 0.3, 0.6)]
	var bloom_colour: Color = colours[rng.randi() % colours.size()]
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf()
		var r := rng.randf_range(0.9, 1.3)
		var at := Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55)
		_ball(holder, r, leaf, at + Vector3(0, r * 0.55, 0), Vector3(1.0, 0.75, 1.0), 10)
		var bloom := NohpaanSurface.material("cloth", bloom_colour, 0.7, 1.0, 0.25)
		for j in 9:
			var b := rng.randf() * TAU
			var up := rng.randf_range(0.35, 0.95)
			var out := sqrt(1.0 - up * up) * r * 0.92
			_ball(holder, rng.randf_range(0.12, 0.2), bloom, at + Vector3(cos(b) * out, r * 0.55 + up * r * 0.75, sin(b) * out), Vector3(1, 0.7, 1), 6)
	level._add_solid(holder.position, Vector3(2.4, 1.6, 2.4))


# --- The monastery ---------------------------------------------------------------------------------------

## Whether a wall letter joins the wall at `c` (the other wall pieces and the gate).
static func _joins(level: Level, c: Vector2i) -> bool:
	return Nohpaan.WALL_LETTERS.contains(level.cell_char(c))


## A piece of the monastery wall: a stone plinth, limewashed plaster with timber ties, and a red tile cap that
## overhangs. It reaches towards each neighbouring piece, so a row of tiles is one wall and a corner a corner.
static func wall_piece(level: Level, c: Vector2i) -> void:
	var holder := _holder(level, c, "Wall")
	var plaster := NohpaanSurface.material("plaster", Color.WHITE, 0.95, 1.0)
	var plinth := NohpaanSurface.material("plinth", Color.WHITE, 0.95, 1.0)
	var timber := NohpaanSurface.material("timber", Color.WHITE, 0.8, 1.0)
	var roof := NohpaanSurface.material("roof", Color.WHITE, 0.7, 2.0)
	var thick := 1.3
	var height := 3.3
	var arms := []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _joins(level, c + d):
			arms.append(d)
	# The post in the middle, then an arm towards each neighbour.
	_box(holder, Vector3(thick + 0.1, height, thick + 0.1), plaster, Vector3(0, height * 0.5, 0))
	_box(holder, Vector3(thick + 0.35, 0.6, thick + 0.35), plinth, Vector3(0, 0.3, 0))
	_box(holder, Vector3(thick + 0.5, 0.28, thick + 0.5), roof, Vector3(0, height + 0.14, 0))
	for d: Vector2i in arms:
		var along_x := d.x != 0
		var size := Vector3(TILE * 0.5 if along_x else thick, height, thick if along_x else TILE * 0.5)
		var at := Vector3(d.x * TILE * 0.25, height * 0.5, d.y * TILE * 0.25)
		_box(holder, size, plaster, at)
		var base := Vector3(size.x + (0.0 if along_x else 0.35), 0.6, size.z + (0.35 if along_x else 0.0))
		_box(holder, base, plinth, Vector3(at.x, 0.3, at.z))
		var cap := Vector3(size.x, 0.28, size.z)
		cap += Vector3(0.0, 0.0, 0.5) if along_x else Vector3(0.5, 0.0, 0.0)
		_box(holder, cap, roof, Vector3(at.x, height + 0.14, at.z))
		# A timber tie across the plaster, high up, and a dark post on the corner side.
		var tie := Vector3(size.x, 0.2, size.z)
		tie += Vector3(0.0, 0.0, 0.1) if along_x else Vector3(0.1, 0.0, 0.0)
		_box(holder, tie, timber, Vector3(at.x, height - 0.35, at.z))
		_box(holder, tie + Vector3(0, 0.1, 0), timber, Vector3(at.x, 1.0, at.z))
	level._near_walls.add(holder)
	if arms.is_empty():
		_box(holder, Vector3(thick, 0.2, thick), timber, Vector3(0, height - 0.35, 0))
	level._add_solid(holder.position, Vector3(TILE if _any_x(arms) else thick, height, TILE if _any_z(arms) else thick) if not arms.is_empty() else Vector3(thick, height, thick))


static func _any_x(arms: Array) -> bool:
	return arms.any(func(d: Vector2i) -> bool: return d.x != 0)


static func _any_z(arms: Array) -> bool:
	return arms.any(func(d: Vector2i) -> bool: return d.y != 0)


## The gate of the monastery: two red timber pillars on stone feet, a lintel with a golden sun-and-moon, and above
## it a two-storeyed tower roof with up-swept eaves. Paper lanterns hang in the passage. The way through stays open.
static func gate(level: Level, c: Vector2i) -> void:
	var holder := _holder(level, c, "Gate")
	var timber := NohpaanSurface.material("timber", Color.WHITE, 0.75, 1.0)
	var plinth := NohpaanSurface.material("plinth", Color.WHITE, 0.95, 1.0)
	var roof := NohpaanSurface.material("roof", Color.WHITE, 0.7, 3.0)
	var plaster := NohpaanSurface.material("plaster", Color.WHITE, 0.95, 1.0)
	var gold := NohpaanSurface.material("gold", Color.WHITE, 0.35, 1.0, 0.3)
	for side in [-1.0, 1.0]:
		var x: float = side * 1.5
		_box(holder, Vector3(1.1, 0.7, 1.1), plinth, Vector3(x, 0.35, 0))
		_cyl(holder, 0.34, 0.38, 4.6, timber, Vector3(x, 3.0, 0), 10)
		_cyl(holder, 0.42, 0.42, 0.2, gold, Vector3(x, 0.78, 0), 10)
		_cyl(holder, 0.42, 0.42, 0.2, gold, Vector3(x, 5.2, 0), 10)
		# A wall stub on the outer side, joining the monastery wall.
		_box(holder, Vector3(0.9, 3.3, 1.3), plaster, Vector3(side * 2.2, 1.65, 0))
	_box(holder, Vector3(3.9, 0.5, 0.7), timber, Vector3(0, 4.7, 0))
	_box(holder, Vector3(3.2, 0.34, 0.5), timber, Vector3(0, 4.1, 0))
	# The sign on the lintel: a gold disc and a pale crescent.
	_cyl(holder, 0.42, 0.42, 0.1, gold, Vector3(-0.35, 4.7, 0.4), 16, Vector3(PI * 0.5, 0, 0))
	_cyl(holder, 0.32, 0.32, 0.12, NohpaanSurface.material("plaster", Color.WHITE, 0.6, 1.0, 0.3), Vector3(0.45, 4.7, 0.4), 16, Vector3(PI * 0.5, 0, 0))
	# Two tiers of roof, the upper smaller, their eaves lifted at the corners.
	for tier in 2:
		var w := 5.6 - tier * 1.8
		var y := 5.5 + tier * 1.25
		var deck := _box(holder, Vector3(w, 0.3, w * 0.62), roof, Vector3(0, y, 0))
		deck.name = "Deck%d" % tier
		for s in [-1.0, 1.0]:
			_box(holder, Vector3(w * 0.5, 0.26, w * 0.62), roof, Vector3(s * w * 0.46, y + 0.16, 0), Vector3(0, 0, -s * 0.3))
		_box(holder, Vector3(w * 0.5, 0.3, 0.3), gold, Vector3(0, y + 0.3, 0))
		if tier == 0:
			_box(holder, Vector3(w - 1.4, 1.0, w * 0.62 - 1.0), plaster, Vector3(0, y + 0.65, 0))
	_cyl(holder, 0.02, 0.14, 1.2, gold, Vector3(0, 8.4, 0), 8)
	for side in [-0.9, 0.9]:
		var lantern := _ball(holder, 0.3, NohpaanSurface.material("cloth", Color(1.0, 0.45, 0.25), 0.6, 1.0, 1.4), Vector3(side, 3.4, 0), Vector3(1, 1.3, 1), 8)
		lantern.name = "Lantern"
	_lamp(holder, Color(1.0, 0.72, 0.42), 1.6, 8.0, Vector3(0, 3.3, 1.0))
	level._near_walls.add(holder)
	# The pillars block, the way between them stays open.
	for side in [-1.0, 1.0]:
		level._add_solid(holder.position + Vector3(side * 1.5, 0, 0), Vector3(1.1, 4.0, 1.1))
		level._add_solid(holder.position + Vector3(side * 2.2, 0, 0), Vector3(0.9, 3.3, 1.3))


## A stupa: three steps of limewashed plinth, a white dome, a gilded square crown and a spire of rings, with strings
## of prayer flags run down from the tip to the ground.
static func stupa(level: Level, c: Vector2i) -> void:
	var holder := _holder(level, c, "Stupa")
	var plaster := NohpaanSurface.material("plaster", Color(1.0, 0.98, 0.94), 0.9, 1.0)
	var plinth := NohpaanSurface.material("plinth", Color.WHITE, 0.95, 1.0)
	var gold := NohpaanSurface.material("gold", Color.WHITE, 0.35, 1.0, 0.25)
	var timber := NohpaanSurface.material("timber", Color.WHITE, 0.8, 1.0)
	_box(holder, Vector3(3.4, 0.4, 3.4), plinth, Vector3(0, 0.2, 0))
	_box(holder, Vector3(2.8, 0.4, 2.8), plaster, Vector3(0, 0.6, 0))
	_box(holder, Vector3(2.2, 0.4, 2.2), plinth, Vector3(0, 1.0, 0))
	_ball(holder, 1.1, plaster, Vector3(0, 1.8, 0), Vector3(1, 0.85, 1), 16)
	_box(holder, Vector3(0.9, 0.7, 0.9), gold, Vector3(0, 2.95, 0))
	_box(holder, Vector3(0.6, 0.12, 0.6), timber, Vector3(0, 3.35, 0))
	for k in 8:
		var r := 0.34 - k * 0.032
		_cyl(holder, r, r + 0.02, 0.14, gold, Vector3(0, 3.5 + k * 0.17, 0), 12)
	_ball(holder, 0.14, gold, Vector3(0, 5.05, 0), Vector3.ONE, 8)
	_cyl(holder, 0.0, 0.1, 0.3, gold, Vector3(0, 5.3, 0), 8)
	# Prayer flags: five colours, hung on strings from the tip to posts round the plinth.
	var colours := [Color(0.2, 0.4, 0.85), Color(0.96, 0.96, 0.92), Color(0.86, 0.2, 0.18), Color(0.2, 0.6, 0.3), Color(0.98, 0.8, 0.2)]
	for s in 4:
		var a := TAU * s / 4.0 + PI * 0.25
		var foot := Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0)
		var tip := Vector3(0, 5.0, 0)
		_cyl(holder, 0.05, 0.07, 2.4, timber, foot + Vector3(0, 1.2, 0), 6)
		for f in 5:
			var t := (f + 0.6) / 5.5
			var at := tip.lerp(foot + Vector3(0, 2.3, 0), t) - Vector3(0, sin(t * PI) * 0.5, 0)
			var flag := _box(holder, Vector3(0.5, 0.42, 0.02), NohpaanSurface.material("cloth", colours[(f + s) % 5], 0.9, 1.0, 0.1), at, Vector3(0, -a, 0))
			flag.name = "Flag"
	_lamp(holder, Color(1.0, 0.85, 0.55), 0.7, 6.0, Vector3(0, 1.6, 1.6))
	level._add_solid(holder.position, Vector3(3.2, 3.0, 3.2))
	level._near_walls.add(holder)


## A prayer wheel: a copper drum on a post, banded in red and gilt, that turns slowly (see NohpaanLife).
static func prayer_wheel(level: Level, c: Vector2i) -> Node3D:
	var holder := _holder(level, c, "PrayerWheel")
	var copper := NohpaanSurface.material("copper", Color.WHITE, 0.4, 2.0)
	var timber := NohpaanSurface.material("timber", Color.WHITE, 0.8, 1.0)
	var gold := NohpaanSurface.material("gold", Color.WHITE, 0.35, 1.0, 0.2)
	var plinth := NohpaanSurface.material("plinth", Color.WHITE, 0.95, 1.0)
	_box(holder, Vector3(1.2, 0.5, 1.2), plinth, Vector3(0, 0.25, 0))
	_cyl(holder, 0.09, 0.09, 1.9, timber, Vector3(0, 1.4, 0), 8)
	var drum := Node3D.new()
	drum.name = "Drum"
	drum.position = Vector3(0, 1.7, 0)
	holder.add_child(drum)
	_cyl(drum, 0.42, 0.42, 0.8, copper, Vector3.ZERO, 14)
	_cyl(drum, 0.44, 0.44, 0.1, gold, Vector3(0, 0.3, 0), 14)
	_cyl(drum, 0.44, 0.44, 0.1, gold, Vector3(0, -0.3, 0), 14)
	_cyl(drum, 0.43, 0.43, 0.2, NohpaanSurface.material("timber", Color(1.2, 1.0, 1.0), 0.7), Vector3.ZERO, 14)
	# Raised glyphs round the drum.
	for k in 8:
		var a := TAU * k / 8.0
		_box(drum, Vector3(0.12, 0.34, 0.05), gold, Vector3(cos(a) * 0.43, 0.0, sin(a) * 0.43), Vector3(0, -a + PI * 0.5, 0))
	_ball(drum, 0.1, gold, Vector3(0, 0.45, 0), Vector3.ONE, 8)
	level._add_solid(holder.position, Vector3(1.2, 2.4, 1.2))
	return drum


# --- The lotus pond ---------------------------------------------------------------------------------------

## One tile of the pond: dark water under a skin of ripples, lily pads and, here and there, a lotus in bloom.
static func pond_cell(level: Level, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + 5
	var holder := _holder(level, c, "Pond")
	var water := StandardMaterial3D.new()
	water.albedo_texture = NohpaanSurface.texture("water")
	water.albedo_color = Color(0.7, 0.9, 0.95, 0.9)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic = 0.3
	water.uv1_scale = Vector3.ONE * 0.5
	var slab := PlaneMesh.new()
	slab.size = Vector2(TILE + 0.05, TILE + 0.05)
	var surface := _mesh(holder, slab, water, Vector3(0, 0.02, 0))
	surface.name = "Water"
	var rock := NohpaanSurface.material("stone", Color.WHITE, 0.95, 2.0)
	# Stones of the bank where the pond meets the meadow.
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if level.cell_char(c + d) == Nohpaan.POND:
			continue
		for k in 5:
			var along := rng.randf_range(-1.8, 1.8)
			var at := Vector3(d.x * 1.95 + (along if d.x == 0 else 0.0), 0.12, d.y * 1.95 + (along if d.y == 0 else 0.0))
			_ball(holder, rng.randf_range(0.28, 0.5), rock, at, Vector3(1.0, 0.6, 0.9), 7)
	var pad := NohpaanSurface.material("leaf", Color(0.7, 1.0, 0.7), 0.7, 1.0)
	for i in 4:
		var r := rng.randf_range(0.35, 0.65)
		var at := Vector3(rng.randf_range(-1.6, 1.6), 0.06, rng.randf_range(-1.6, 1.6))
		_cyl(holder, r, r, 0.03, pad, at, 14)
	if rng.randf() < 0.75:
		var at := Vector3(rng.randf_range(-1.2, 1.2), 0.08, rng.randf_range(-1.2, 1.2))
		var petal := NohpaanSurface.material("cloth", Color(1.0, 0.7, 0.82), 0.6, 1.0, 0.35)
		for k in 8:
			var a := TAU * k / 8.0
			_ball(holder, 0.17, petal, at + Vector3(cos(a) * 0.16, 0.14, sin(a) * 0.16), Vector3(0.6, 1.5, 0.9), 6).rotation = Vector3(0, -a, 0.55)
		_ball(holder, 0.09, NohpaanSurface.material("gold", Color.WHITE, 0.5, 1.0, 0.4), at + Vector3(0, 0.18, 0), Vector3.ONE, 6)
	level._add_solid(holder.position, Vector3(TILE, 0.6, TILE))


# --- The mountains ----------------------------------------------------------------------------------------

static var _peak_material: ShaderMaterial = null


## A peak of the mountains round the valley: a cone roughened into crags by its shader, with turf on the low slopes
## and snow high up. `base` is where it stands on the wall tops (4 metres up).
static func peak(parent: Node3D, base: Vector3, radius: float, height: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	if _peak_material == null:
		_peak_material = ShaderMaterial.new()
		_peak_material.shader = preload("res://shaders/nohpaan_peak.gdshader")
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * rng.randf_range(0.02, 0.1)
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 12
	var node := _mesh(parent, mesh, _peak_material, base + Vector3(0, height * 0.5 - 0.4, 0), Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05)))
	return node


# --- Paving, signs and the sealed gates -------------------------------------------------------------------

## A square of slate flagstones laid on the ground (the hall and the cloister paths).
static func flagstone(level: Level, c: Vector2i) -> void:
	var holder := _holder(level, c, "Flags")
	var quad := PlaneMesh.new()
	quad.size = Vector2(TILE, TILE)
	_mesh(holder, quad, NohpaanSurface.material("slate", Color.WHITE, 0.85, 1.0), Vector3(0, 0.1, 0))


## The gate to a place that is not open yet: a stone arch in the rock with a door of old timber bound in iron,
## frozen shut under glittering ice, and a mist that does not lift.
static func sealed_gate(level: Level, c: Vector2i, name: String) -> void:
	var holder := _holder(level, c, "Sealed")
	holder.name = "Sealed_" + name
	var stone := NohpaanSurface.material("stone", Color.WHITE, 0.95, 2.0)
	var plinth := NohpaanSurface.material("plinth", Color.WHITE, 0.95, 1.0)
	var wood := NohpaanSurface.material("wood", Color(0.8, 0.8, 0.85), 0.9, 1.0)
	var ice := NohpaanSurface.material("ice", Color(0.9, 1.0, 1.0), 0.12, 1.0, 0.6)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.albedo_color = Color(0.85, 0.96, 1.0, 0.7)
	var plaster := NohpaanSurface.material("plaster", Color.WHITE, 0.95, 1.0)
	var timber := NohpaanSurface.material("timber", Color.WHITE, 0.8, 1.0)
	var gold := NohpaanSurface.material("gold", Color.WHITE, 0.35, 1.0, 0.3)
	for side in [-1.0, 1.0]:
		_box(holder, Vector3(1.1, 4.2, 1.4), plaster, Vector3(side * 1.6, 2.1, -1.2))
		_box(holder, Vector3(1.3, 0.5, 1.6), plinth, Vector3(side * 1.6, 0.25, -1.2))
		_cyl(holder, 0.3, 0.3, 0.3, gold, Vector3(side * 1.6, 4.35, -1.2), 10)
	_box(holder, Vector3(4.6, 0.7, 1.6), timber, Vector3(0, 4.55, -1.2))
	_box(holder, Vector3(3.4, 0.3, 1.0), gold, Vector3(0, 4.1, -1.3))
	# Snow drifted against the foot of the ice.
	for k in 5:
		_ball(holder, 0.45, ice, Vector3(-1.1 + k * 0.55, 0.15, -0.8), Vector3(1.3, 0.5, 1.0), 6)
	_box(holder, Vector3(2.2, 3.7, 0.3), wood, Vector3(0, 1.85, -1.5))
	for y in [0.8, 2.0, 3.1]:
		_box(holder, Vector3(2.25, 0.14, 0.38), NohpaanSurface.material("plinth", Color(0.5, 0.5, 0.55), 0.5), Vector3(0, y, -1.45))
	# The ice: a lumpy sheet over the door and crystals standing out of it.
	_box(holder, Vector3(2.3, 3.8, 0.35), ice, Vector3(0, 1.9, -1.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + 9
	for i in 9:
		var spike := _cyl(holder, 0.0, rng.randf_range(0.12, 0.22), rng.randf_range(0.5, 1.2), ice, Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.3, 3.4), -1.1), 5,
				Vector3(rng.randf_range(-0.5, 0.5) - PI * 0.4, 0, rng.randf_range(-0.4, 0.4)))
		spike.name = "Crystal"
	_lamp(holder, Color(0.6, 0.85, 1.0), 1.1, 7.0, Vector3(0, 2.4, 0.2))
	level._add_solid(holder.position + Vector3(0, 0, -1.0), Vector3(TILE, 4.0, 1.8))

class_name SternParts
extends RefCounted
## What the pieces of Sternhall look like (see SternHall): the star reliefs
## in the walls, the bottomless chasm, the crumbling flagstones over it, the
## listening eyes, the lectern with the tome, the potion shelf, the anvil,
## the heap of rubble, the old drain and the warden's key ring. Only looks
## and solid boxes: what they do is up to SternHall.

## The faint gold of the stars carved into the keep's stone, and the violet
## of its magic.
const STAR_GOLD := Color(1.0, 0.82, 0.42)
const VIOLET := Color(0.66, 0.42, 1.0)
## How deep the chasm looks: its black floor lies this far down.
const CHASM_DEPTH := 9.0

static var _mats := {}


## A plain material, cached: `glow` makes it shine in its own colour,
## `alpha` below 1 makes it see-through, `flat` ignores the light.
static func material(colour: Color, glow := 0.0, alpha := 1.0, flat := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [colour.to_html(), glow, alpha, flat]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(colour, alpha)
		m.roughness = 0.85
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if flat:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, mat, pos, rot)


static func _light(parent: Node3D, colour: Color, energy: float, reach: float, pos := Vector3.ZERO) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.position = pos
	parent.add_child(light)
	return light


## A five-pointed star, `outer` and `inner` its radii, `depth` thick along
## +z (its face looks along +z).
static func star_mesh(outer: float, inner: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector2] = []
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := PI * 0.5 + TAU * i / 10.0
		rim.append(Vector2(cos(a), sin(a)) * r)
	for i in 10:
		var a := rim[i]
		var b := rim[(i + 1) % 10]
		# The face, a fan round the middle.
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(0, 0, depth))
		st.add_vertex(Vector3(a.x, a.y, depth))
		st.add_vertex(Vector3(b.x, b.y, depth))
		# The side.
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		st.set_normal(n)
		st.add_vertex(Vector3(a.x, a.y, depth))
		st.add_vertex(Vector3(a.x, a.y, 0))
		st.add_vertex(Vector3(b.x, b.y, depth))
		st.add_vertex(Vector3(b.x, b.y, depth))
		st.add_vertex(Vector3(a.x, a.y, 0))
		st.add_vertex(Vector3(b.x, b.y, 0))
	return st.commit()


## A round stone slab with a star carved on it, set into the wall at
## `wall_pos` (the middle of the wall's foot, on the room's side), facing the
## room (`rot` as Level turns a wall piece), its middle `height` metres up.
## A relief set high hangs a little lower than its centre of reach would
## suggest, so it reads from the camera. Returns the star, which lights up
## when the relief is pressed (see press_relief).
static func relief(level: Level, wall_pos: Vector3, rot: float, height: float) -> MeshInstance3D:
	var holder := Node3D.new()
	var facing := Vector3(sin(rot), 0, cos(rot))
	holder.position = wall_pos + facing * 0.36 + Vector3(0, height, 0)
	holder.rotation.y = rot
	level.add_child(holder)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.66
	disc.height = 0.14
	disc.radial_segments = 20
	_mesh(holder, disc, material(Color(0.46, 0.44, 0.42)), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.02
	ring.radial_segments = 20
	_mesh(holder, ring, material(Color(0.32, 0.3, 0.29)), Vector3(0, 0, 0.07), Vector3(PI * 0.5, 0, 0))
	return _mesh(holder, star_mesh(0.42, 0.18, 0.06), material(STAR_GOLD, 0.35), Vector3(0, 0, 0.07))


## The star of a pressed relief sinks in and shines.
static func press_relief(star: MeshInstance3D, at_once := false) -> void:
	if not is_instance_valid(star):
		return
	star.material_override = material(STAR_GOLD, 2.6)
	if at_once:
		star.position.z = 0.02
		return
	var tween: Tween = star.create_tween()
	tween.tween_property(star, "position:z", 0.02, 0.35).set_trans(Tween.TRANS_BACK)
	_light(star, STAR_GOLD, 1.6, 4.0, Vector3(0, 0, 0.4))


## The chasm under a tile (`*`, and the pit a crumbling flagstone falls
## into): a black floor far below and dark walls going down along every
## edge that does not open onto more chasm, with faint stars in the dark.
static func chasm(level: Level, c: Vector2i, is_pit: Callable, stars: Array) -> void:
	var pos := level.cell_to_world(c)
	var tile := Level.TILE
	var black := material(Color(0.01, 0.008, 0.02), 0.0, 1.0, true)
	_box(level, Vector3(tile, 0.1, tile), black, pos + Vector3(0, -CHASM_DEPTH, 0))
	var side := material(Color(0.05, 0.045, 0.07), 0.0, 1.0, true)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_pit.call(c + d):
			continue
		var edge := pos + Vector3(d.x, 0, d.y) * tile * 0.5 + Vector3(0, -CHASM_DEPTH * 0.5, 0)
		var size := Vector3(0.1, CHASM_DEPTH, tile) if d.x != 0 else Vector3(tile, CHASM_DEPTH, 0.1)
		_box(level, size, side, edge)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	for i in 3:
		stars.append(pos + Vector3(rng.randf_range(-1.8, 1.8), -rng.randf_range(2.5, CHASM_DEPTH - 0.5), rng.randf_range(-1.8, 1.8)))


## All the stars of the chasm as one mesh: little glowing dots.
static func starfield(level: Level, stars: Array) -> void:
	if stars.is_empty():
		return
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = stars.size()
	for i in stars.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * randf_range(0.6, 1.6)), stars[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material(Color(0.85, 0.8, 1.0), 3.0, 1.0, true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mmi)


## A flagstone over the chasm: a floor tile on a holder of its own that can
## shake, fall and rise again, a little redder than the safe floor, with
## cracks across it.
static func flagstone(level: Level, c: Vector2i) -> Node3D:
	var holder := Node3D.new()
	holder.position = level.cell_to_world(c)
	level.add_child(holder)
	var tile := level._place("floor_tile_large", Vector3.ZERO, level._random_quarter_turn(), holder)
	for mi: MeshInstance3D in tile.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var tinted: StandardMaterial3D = mat.duplicate()
			tinted.albedo_color = tinted.albedo_color * Color(1.0, 0.86, 0.8)
			mi.material_override = tinted
	var crack := material(Color(0.08, 0.06, 0.05))
	_box(holder, Vector3(2.6, 0.03, 0.08), crack, Vector3(0.2, 0.06, -0.4), Vector3(0, 0.6, 0))
	_box(holder, Vector3(1.6, 0.03, 0.07), crack, Vector3(-0.6, 0.06, 0.7), Vector3(0, -0.9, 0))
	# Under the tile: its thickness, so a falling stone is a block, not a sheet.
	_box(holder, Vector3(Level.TILE * 0.96, 0.6, Level.TILE * 0.96), material(Color(0.3, 0.27, 0.25)), Vector3(0, -0.3, 0))
	return holder


## A listening eye: a short stone pillar with a great eye on top that turns
## after sounds. Returns {"node", "ball", "iris", "light"}.
static func eye(level: Level, pos: Vector3) -> Dictionary:
	var holder := Node3D.new()
	holder.position = pos
	level.add_child(holder)
	var post := level._place("pillar", Vector3.ZERO, 0.0, holder)
	post.scale = Vector3(0.55, 0.36, 0.55)
	var ball := Node3D.new()
	ball.position = Vector3(0, 1.85, 0)
	holder.add_child(ball)
	var white := SphereMesh.new()
	white.radius = 0.42
	white.height = 0.84
	_mesh(ball, white, material(Color(0.86, 0.82, 0.74)))
	var iris_mesh := SphereMesh.new()
	iris_mesh.radius = 0.2
	iris_mesh.height = 0.4
	var iris := _mesh(ball, iris_mesh, material(VIOLET, 1.2), Vector3(0, 0, 0.3))
	iris.scale = Vector3(1, 1, 0.5)
	var pupil := SphereMesh.new()
	pupil.radius = 0.09
	pupil.height = 0.18
	_mesh(ball, pupil, material(Color(0.02, 0.0, 0.04)), Vector3(0, 0, 0.39)).scale = Vector3(1, 1, 0.4)
	var light := _light(holder, VIOLET, 0.6, 3.5, Vector3(0, 1.9, 0))
	level._add_solid(pos, Vector3(1.4, 2.4, 1.4))
	return {"node": holder, "ball": ball, "iris": iris, "light": light}


## The lectern in the middle of the vault: a stone stand with a slanted
## top, the tome's glow over it.
static func lectern(level: Level, pos: Vector3) -> OmniLight3D:
	var holder := Node3D.new()
	holder.position = pos
	level.add_child(holder)
	var stone := material(Color(0.5, 0.48, 0.46))
	_box(holder, Vector3(1.2, 0.2, 1.0), stone, Vector3(0, 0.1, 0))
	_box(holder, Vector3(0.5, 1.0, 0.4), stone, Vector3(0, 0.7, 0))
	_box(holder, Vector3(1.1, 0.12, 0.8), stone, Vector3(0, 1.25, 0.05), Vector3(-0.35, 0, 0))
	var star := _mesh(holder, star_mesh(0.3, 0.13, 0.04), material(STAR_GOLD, 1.0), Vector3(0, 0.75, 0.21))
	star.rotation.y = 0.0
	var glow := _light(holder, VIOLET, 2.4, 7.0, Vector3(0, 2.0, 0))
	var sparks := Effects.make_sparkles(VIOLET)
	sparks.position = Vector3(0, 1.6, 0)
	holder.add_child(sparks)
	level._add_solid(pos, Vector3(1.2, 1.4, 1.0))
	return glow


## A wooden rack of potion bottles against the wall behind tile c.
static func shelf(level: Level, c: Vector2i) -> void:
	var pos := level.cell_to_world(c)
	var rot := level._facing_room(c)
	var facing := Vector3(sin(rot), 0, cos(rot))
	var holder := Node3D.new()
	holder.position = pos - facing * 1.0
	holder.rotation.y = rot
	level.add_child(holder)
	level._add_kit_part(["SM_WoodenContainerWithBottles", "props", Vector3.ZERO, Vector3.ONE * 2.0, PI], holder)
	_light(holder, Color(1.0, 0.35, 0.35), 0.8, 3.0, Vector3(0, 1.6, 0.8))
	level._add_solid(pos - facing * 0.6, Vector3(2.4, 2.2, 1.6))


## A heap of rubble that fills the gap at c (the hero climbs it from a
## crate, see SternLedge), its long side across the gap.
static func rubble(level: Level, c: Vector2i, across_x: bool) -> void:
	var pos := level.cell_to_world(c)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = 0.0 if across_x else PI * 0.5
	level.add_child(holder)
	var stone := material(Color(0.42, 0.4, 0.38))
	var dark := material(Color(0.32, 0.3, 0.29))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	# The body of the heap, then broken blocks heaped on it.
	_box(holder, Vector3(Level.TILE, SternLedge.HEIGHT - 0.3, SternLedge.DEPTH), dark, Vector3(0, (SternLedge.HEIGHT - 0.3) * 0.5, 0))
	for i in 9:
		var size := Vector3(rng.randf_range(0.6, 1.3), rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 1.0))
		var at := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(0.2, SternLedge.HEIGHT - 0.4), rng.randf_range(-0.7, 0.7))
		_box(holder, size, stone, at, Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
	for i in 4:
		var at := Vector3(rng.randf_range(-1.6, 1.6), 0.25, rng.randf_range(-1.2, 1.2) * (1.0 if i % 2 == 0 else -1.0))
		_box(holder, Vector3(0.6, 0.5, 0.5), stone, at, Vector3(0, rng.randf() * TAU, 0))


## The end of the old drain: iron rungs up the wall to a grate with a little
## daylight falling through it.
static func drain(level: Level, c: Vector2i) -> void:
	var pos := level.cell_to_world(c)
	var open := level._open_side(c)
	var away := Vector3(pos.x - level.cell_to_world(open).x, 0, pos.z - level.cell_to_world(open).z).normalized()
	var holder := Node3D.new()
	holder.position = pos
	level.add_child(holder)
	var iron := material(Color(0.2, 0.18, 0.17))
	var wall := away * 1.5
	for i in 6:
		var rung := _box(holder, Vector3(1.0, 0.07, 0.07), iron, wall + Vector3(0, 0.5 + i * 0.6, 0))
		rung.rotation.y = atan2(away.x, away.z)
	_box(holder, Vector3(0.08, 3.8, 0.08), iron, wall + Vector3(-0.55, 1.9, 0).rotated(Vector3.UP, atan2(away.x, away.z)))
	_box(holder, Vector3(0.08, 3.8, 0.08), iron, wall + Vector3(0.55, 1.9, 0).rotated(Vector3.UP, atan2(away.x, away.z)))
	var ray := material(Color(0.85, 0.9, 1.0), 0.6, 0.18, true)
	_box(holder, Vector3(1.4, 4.0, 1.4), ray, wall * 0.6 + Vector3(0, 2.0, 0))
	_light(holder, Color(0.85, 0.9, 1.0), 1.4, 6.0, Vector3(0, 3.2, 0))
	var puddle := CylinderMesh.new()
	puddle.top_radius = 1.1
	puddle.bottom_radius = 1.1
	puddle.height = 0.02
	_mesh(holder, puddle, material(Color(0.12, 0.14, 0.16), 0.0, 0.8), Vector3(0, 0.03, 0))
	level._add_solid(pos + wall * 0.6, Vector3(1.6, 3.0, 1.6))


## The warden's key ring, lying where he fell, glinting.
static func key_ring(level: Level, pos: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(pos.x, 0.0, pos.z)
	level.add_child(holder)
	var ring := level._place("keyring", Vector3(0, 0.35, 0), 0.0, holder)
	ring.scale = Vector3.ONE * 1.6
	_light(holder, STAR_GOLD, 1.4, 3.0, Vector3(0, 0.8, 0))
	var sparks := Effects.make_sparkles(STAR_GOLD)
	sparks.position = Vector3(0, 0.6, 0)
	holder.add_child(sparks)
	return holder


## A flat ring on the floor that warns where something will strike.
static func warning_ring(level: Level, pos: Vector3, radius: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Effects.ring_mesh(maxf(0.05, radius - 0.18), radius, 0.0, 0.04, 28, material(colour, 1.6, 0.85, true))
	mi.position = Vector3(pos.x, 0.05, pos.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mi)
	return mi


## Gives a falling stone a rough, faceted body: a flat-faced lump of rock with
## grainy, cracked stone and a varied grey-brown tint. The three meshes and
## materials are built once and shared by every stone.
static var _rock_meshes: Array[Mesh] = []
static var _rock_mats: Array[StandardMaterial3D] = []


static func rocky(rock: Node3D) -> void:
	if _rock_meshes.is_empty():
		_build_rocks()
	for child in rock.get_children():
		child.queue_free()
	var pick := randi() % _rock_meshes.size()
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_meshes[pick]
	mi.material_override = _rock_mats[pick]
	mi.scale = Vector3(randf_range(0.9, 1.3), randf_range(0.8, 1.1), randf_range(0.9, 1.3))
	mi.rotation = Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	mi.position.y = 0.55
	rock.add_child(mi)


static func _build_rocks() -> void:
	var grain := FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_CELLULAR
	grain.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	grain.frequency = 0.07
	grain.seed = 41
	var speckle := FastNoiseLite.new()
	speckle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	speckle.frequency = 0.12
	speckle.fractal_octaves = 4
	speckle.seed = 17
	var height := Image.create(64, 64, false, Image.FORMAT_L8)
	var colour := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var crack := clampf(grain.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
			var fine := speckle.get_noise_2d(x, y) * 0.5 + 0.5
			var h := clampf(crack * 0.6 + fine * 0.4, 0.0, 1.0)
			height.set_pixel(x, y, Color(h, h, h))
			var v := 0.55 + 0.45 * h
			colour.set_pixel(x, y, Color(v, v * 0.97, v * 0.92))
	height.bump_map_to_normal_map(5.0)
	var normal_tex := ImageTexture.create_from_image(height)
	var colour_tex := ImageTexture.create_from_image(colour)
	var tints := [Color(0.62, 0.58, 0.52), Color(0.5, 0.48, 0.47), Color(0.68, 0.6, 0.5)]
	for i in tints.size():
		_rock_meshes.append(_rock_mesh(100 + i))
		var m := StandardMaterial3D.new()
		m.albedo_color = tints[i]
		m.albedo_texture = colour_tex
		m.normal_enabled = true
		m.normal_texture = normal_tex
		m.normal_scale = 1.3
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.4
		_rock_mats.append(m)


## An irregular lump about a metre across: a squashed sphere whose corners are
## pushed in and out, every face flat.
static func _rock_mesh(seed_value: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings := 6
	var segs := 8
	var grid: Array = []
	for r in rings + 1:
		var row: Array[Vector3] = []
		var pitch := PI * r / rings
		for sg in segs:
			var a := TAU * sg / segs
			var rad := 0.5 * rng.randf_range(0.7, 1.2)
			if r == 0 or r == rings:
				rad = 0.5 * rng.randf_range(0.8, 1.0)
			var p := Vector3(sin(pitch) * cos(a), cos(pitch) * 0.8, sin(pitch) * sin(a)) * rad
			row.append(p)
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings:
		for sg in segs:
			var s2 := (sg + 1) % segs
			var a: Vector3 = grid[r][sg]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s2]
			var d: Vector3 = grid[r + 1][sg]
			for tri: Array in [[a, b, c], [a, c, d]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
				if n.length() < 0.0001:
					continue
				n = n.normalized()
				var centre: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				# The normal points out of the rock; Godot wants the corners
				# clockwise seen from outside, which makes the cross product point in.
				if n.dot(centre) < 0.0:
					n = -n
				else:
					tri = [tri[0], tri[2], tri[1]]
				for v: Vector3 in tri:
					st.set_normal(n)
					st.add_vertex(v)
	return st.commit()


## Makes every mesh under `node` a pale, see-through glow: a ghost.
static func ghostly(node: Node, colour: Color) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material(colour, 0.8, 0.45)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

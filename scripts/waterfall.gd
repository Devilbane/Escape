class_name Waterfall
extends Node3D
## The spring of the river (map letter "∩"): in the far west of the farming valley a stream tumbles down
## the mountain's face, over a shelf of rock, and falls into the river's first pool. Behind the curtain of
## water, in a notch of the cliff, lies the way to a hidden cave, disguised as plain rock (a secret
## entrance looks like the walls around it), reached by a causeway of stepping stones through the pool.
##
## The letter marks the notch (one tile cut into the rock face, see Mountains.is_rock): its middle is
## the porch, the rock shelf with the water's brow lies over it, and the causeway of path tiles runs
## south from it through the pool. Everything is built from that one tile.
##
## The water is a handful of sheets (see waterfall.gdshader): the stream laid on the rock face as it
## is drawn (Mountains.surface_at), the curtain hanging from the shelf's brow, and a thin runnel down
## each side. Spray rises where it lands. In winter the whole fall is frozen (see Outdoor.set_ice): the
## streaks stand still as ridges of ice, icicles hang from the brow, a mound of ice sits at the foot,
## and snow (see Outdoor.set_snow) lies on the shelf and the boulders.
##
## Heights (metres): the shelf's brow, and how far from the notch's middle things lie (u across, v out
## from the rock face to the south).

const W := preload("res://scripts/weathered_props.gd")
const SHEET := preload("res://shaders/waterfall.gdshader")

const TILE := 4.0
const ROOF := 6.6
## The buttresses and the stacked boulders are laid out for a shelf 4.3 m up; this stretches them to ROOF.
const K := ROOF / 4.3
const BROW_V := 1.0
const CURTAIN_V := 1.25
const CURTAIN_WIDTH := 5.4
## From where the stream is laid on the rock, north of the notch, to the shelf's back edge.
const STREAM_FROM_V := -17.0
const SHELF_BACK_V := -5.8
## The runnels at either side: how far from the middle, from how far up.
const RUNNEL_U := 4.3
const RUNNEL_FROM_V := -9.0
const RUNNEL_WIDTH := 1.5
const LIFT := 0.14
## How many tiles of causeway run south from the notch's tile.
const CAUSEWAY := 4
## The ice and snow show from these amounts.
const ICE_FROM := 0.25
const SNOW_FROM := 0.3

var ice := 0.0
var snow := 0.0
var _sheets: Array[ShaderMaterial] = []
var _icicles := Node3D.new()
var _ice_foot := Node3D.new()
var _snow_caps := Node3D.new()
var _sprays: Array[CPUParticles3D] = []


static func is_letter(ch: String) -> bool:
	return ch == "∩"


## Builds the fall at the notch tile `c`.
static func build(lvl: Outdoor, c: Vector2i) -> Waterfall:
	var fall := Waterfall.new()
	fall.name = "Waterfall"
	fall.position = lvl.cell_to_world(c)
	lvl.add_child(fall)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lvl.level_name + "wasserfall")
	fall._rocks(rng)
	fall._causeway(rng)
	fall._doorway(rng)
	fall._ice(rng)
	fall._snow(rng)
	# The rock plug stops the hero at the back of the porch.
	lvl._add_solid(fall.position + Vector3(0, 0, -1.3), Vector3(4.0, 3.0, 1.2))
	lvl.waterfall = fall
	return fall


## How much of the water is frozen, 0 to 1.
func set_ice(value: float) -> void:
	ice = clampf(value, 0.0, 1.0)
	for mat in _sheets:
		mat.set_shader_parameter("ice", ice)
	_icicles.visible = ice > ICE_FROM
	_icicles.scale = Vector3(1, clampf((ice - ICE_FROM) / 0.6, 0.0, 1.0), 1)
	_ice_foot.visible = ice > ICE_FROM
	_ice_foot.scale = Vector3.ONE * clampf((ice - ICE_FROM) / 0.6, 0.05, 1.0)
	for puff in _sprays:
		var on := ice < 0.7
		if puff.emitting != on:
			puff.emitting = on


## How thickly the snow lies, 0 to 1.
func set_snow(cover: float) -> void:
	snow = cover
	_snow_caps.visible = cover > SNOW_FROM
	_snow_caps.scale = Vector3(1, clampf((cover - SNOW_FROM) / 0.5, 0.05, 1.0), 1)
	for mat in _sheets:
		mat.set_shader_parameter("snow", clampf(cover, 0.0, 1.0))


# --- The rock -------------------------------------------------------------

## A boulder: a sphere pushed in and out by noise, so it is rounded and lumpy, painted and weathered like
## the mountain (see Mountains and AgedStone.rock_material), sunk a little into the ground.
static func rock_mesh(radii: Vector3, seed_value: int, colour: Color) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 9
	var source := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.1
	var colours := PackedColorArray()
	for i in verts.size():
		var v := verts[i] * 2.0
		var bump := 1.0 + 0.34 * noise.get_noise_3d(v.x * 1.7, v.y * 1.7, v.z * 1.7) + 0.08 * noise.get_noise_3d(v.x * 5.0, v.y * 5.0, v.z * 5.0)
		v = Vector3(v.x * radii.x, maxf(v.y * radii.y * bump, -radii.y * 0.45), v.z * radii.z) * (Vector3(bump, 1.0, bump))
		verts[i] = v
		# Darker underneath and in the hollows, paler on top.
		colours.append(colour * (0.82 + 0.22 * clampf(v.y / radii.y * 0.5 + 0.5, 0.0, 1.0)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.index()
	st.generate_normals()
	return st.commit()


func _rock(at: Vector3, radii: Vector3, rng: RandomNumberGenerator, parent: Node3D = self, material: Material = null, colour := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var tint := colour
	if colour.a == 0.0:
		tint = Mountains.ROCK.lerp(Mountains.ROCK_DARK, rng.randf_range(0.0, 0.55))
		if rng.randf() < 0.3:
			tint = tint.lerp(Mountains.MOSS, 0.35)
	var mi := MeshInstance3D.new()
	mi.mesh = rock_mesh(radii, rng.randi(), tint)
	mi.material_override = material if material != null else AgedStone.rock_material()
	mi.position = at
	mi.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
	parent.add_child(mi)
	return mi


func _rocks(rng: RandomNumberGenerator) -> void:
	# The shelf the water pours from: a long slab over the notch, with the cliff behind it, and a rough
	# brow of smaller stones along its edge.
	_rock(Vector3(0, ROOF - 0.55, -1.7), Vector3(3.9, 0.85, 3.4), rng)
	_rock(Vector3(-0.8, ROOF - 0.7, -3.4), Vector3(3.4, 0.95, 2.2), rng)
	_rock(Vector3(1.0, ROOF - 0.65, -3.0), Vector3(3.3, 0.9, 2.4), rng)
	for i in 7:
		var u := lerpf(-2.7, 2.7, i / 6.0) + rng.randf_range(-0.15, 0.15)
		_rock(Vector3(u, ROOF - 0.55, BROW_V - 0.15 + rng.randf_range(-0.1, 0.1)), Vector3(0.62, 0.4, 0.5) * rng.randf_range(0.9, 1.25), rng)
	# The back of the notch above the doorway, so the curtain hangs before rock all the way up.
	_rock(Vector3(0, 4.6, -1.9), Vector3(2.6, 1.3, 1.1), rng)
	_rock(Vector3(-1.4, 5.8, -2.2), Vector3(1.6, 1.0, 1.2), rng)
	_rock(Vector3(1.4, 5.8, -2.2), Vector3(1.6, 1.0, 1.2), rng)
	# Buttresses at either side: boulders heaped from the ground up to the shelf, ivy-green with moss.
	for side in [-1.0, 1.0]:
		var s: float = side
		_rock(Vector3(s * 2.9, 0.9 * K, -0.6), Vector3(1.7, 1.2 * K, 1.5), rng)
		_rock(Vector3(s * 3.1, 0.5, 1.2), Vector3(1.3, 0.8, 1.2), rng)
		_rock(Vector3(s * 2.6, 2.2 * K, -1.6), Vector3(1.5, 1.2 * K, 1.6), rng)
		_rock(Vector3(s * 3.3, 2.1 * K, 0.2), Vector3(1.2, 1.1 * K, 1.1), rng)
		_rock(Vector3(s * 2.9, 3.4 * K, -1.3), Vector3(1.5, 1.0 * K, 1.7), rng)
		_rock(Vector3(s * 4.0, 1.3 * K, -1.8), Vector3(1.4, 1.5 * K, 1.6), rng)
		# Fallen blocks in the pool beside the causeway.
		_rock(Vector3(s * 5.3, 0.15, 3.5), Vector3(0.95, 0.7, 0.8), rng)
		_rock(Vector3(s * 3.9, 0.1, 5.6), Vector3(0.6, 0.45, 0.55), rng)
		_rock(Vector3(s * 7.2, 0.1, 2.4), Vector3(0.8, 0.6, 0.7), rng)
	# Boulders at the foot of the runnels.
	for side in [-1.0, 1.0]:
		var s: float = side
		for k in 3:
			_rock(Vector3(s * (RUNNEL_U + rng.randf_range(-1.1, 1.1)), 0.1, 2.0 + rng.randf_range(0.0, 1.2)), Vector3(0.55, 0.4, 0.5) * rng.randf_range(0.8, 1.4), rng)


## Flat stones laid as steps through the pool, from the porch south over the path tiles: slabs of the cliff's
## own rock, rounded and weathered like it.
func _causeway(rng: RandomNumberGenerator) -> void:
	var tint := Color(0.6, 0.58, 0.55)
	# The porch floor: wet flagstones.
	for p: Vector3 in [Vector3(-1.1, 0.0, -0.9), Vector3(1.0, 0.0, -0.8), Vector3(-0.9, 0.0, 0.8), Vector3(1.1, 0.0, 0.8), Vector3(0.0, 0.0, 0.0)]:
		_rock(p, Vector3(rng.randf_range(1.0, 1.25), 0.2, rng.randf_range(0.9, 1.15)), rng, self, null, tint)
	var length := TILE * CAUSEWAY
	var v := 2.6
	while v < length + 2.0:
		var sway := sin(v * 0.9) * 0.35
		_rock(Vector3(sway + rng.randf_range(-0.2, 0.2), 0.0, v), Vector3(rng.randf_range(1.0, 1.35), 0.2, rng.randf_range(0.7, 0.95)), rng, self, null, tint)
		if rng.randf() < 0.7:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			_rock(Vector3(sway + side * rng.randf_range(1.3, 1.7), 0.0, v + rng.randf_range(-0.5, 0.5)), Vector3(rng.randf_range(0.35, 0.55), 0.14, rng.randf_range(0.35, 0.55)), rng, self, null, tint)
		v += rng.randf_range(1.0, 1.4)


## The way into the hill is disguised as the rock around it: the notch's back is plugged with boulders of
## the very same stone (painted and weathered like the cliff), no dark opening, no frame. The only hint is
## a faint wave worn into the middle boulder, which the spray keeps wet and mossy.
func _doorway(rng: RandomNumberGenerator) -> void:
	var back := -1.45
	_rock(Vector3(-1.0, 1.1, back), Vector3(1.35, 1.35, 0.9), rng)
	_rock(Vector3(1.0, 1.1, back), Vector3(1.35, 1.35, 0.9), rng)
	_rock(Vector3(0.0, 1.2, back - 0.2), Vector3(1.6, 1.5, 0.9), rng)
	_rock(Vector3(0.0, 2.5, back - 0.1), Vector3(2.4, 0.9, 0.95), rng)
	var b := W.Builder.new()
	# The wave: three faint, shallow lines in the same grey as the rock.
	for row in 3:
		var y := 0.9 + row * 0.42
		for k in 6:
			var x := -0.5 + k * 0.2
			var dy := 0.05 * (1.0 if k % 2 == 0 else -1.0)
			b.box(Vector3(x, y + dy, back + 0.62), Vector3(0.19, 0.045, 0.03), Color(0.4, 0.38, 0.36), W.STONE)
	b.finish(self, Vector3.ZERO, false)


# --- The water --------------------------------------------------------------

func _sheet_material(width: float, length: float, ledge := -1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHEET
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("length_m", length)
	mat.set_shader_parameter("ledge_at", ledge)
	mat.set_shader_parameter("ice", ice)
	_sheets.append(mat)
	return mat


## A strip of water along `centre` (points from the top downwards), `widths` wide at each point, laid
## on the rock where `follow` is true (each edge at the height of the rock under it), UV.y running down.
func _ribbon(centre: Array, widths: Array, rock: Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := []
	var run := 0.0
	for i in centre.size():
		var p: Vector3 = centre[i]
		if i > 0:
			run += (p - (centre[i - 1] as Vector3)).length()
		var along: Vector3 = ((centre[mini(i + 1, centre.size() - 1)] as Vector3) - (centre[maxi(i - 1, 0)] as Vector3))
		var flat := Vector3(along.x, 0, along.z)
		var across := Vector3.RIGHT
		if flat.length() > 0.05:
			across = Vector3(-flat.z, 0, flat.x).normalized()
		var half: float = widths[i] * 0.5
		var pair := []
		for side in [-1.0, 1.0]:
			var q: Vector3 = p + across * half * side
			if rock[i]:
				var h := Mountains.surface_at(get_parent() as Level, global_position.x + q.x, global_position.z + q.z)
				if h != INF:
					q.y = maxf(h + LIFT, p.y - 0.8)
			pair.append(q)
		rows.append([pair[0], pair[1], run])
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var quad := [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			var pts := [quad[tri[0]], quad[tri[1]], quad[tri[2]]]
			var n := (((pts[1][0] as Vector3) - (pts[0][0] as Vector3)).cross((pts[2][0] as Vector3) - (pts[0][0] as Vector3))).normalized()
			if n.y < 0.0:
				n = -n
			for pt in pts:
				st.set_normal(n)
				st.set_uv(Vector2(pt[1], pt[2]))
				st.add_vertex(pt[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A hanging sheet of water: a grid, hung from `top` to the floor, its surface rippled a little in depth.
func _curtain(width: float, top: float, v: float, depth_swing: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 14
	var rows := 12
	var noise := FastNoiseLite.new()
	noise.seed = int(v * 100.0)
	noise.frequency = 0.9
	var grid := []
	for r in rows + 1:
		var line := []
		var t := float(r) / rows
		for k in cols + 1:
			var s := float(k) / cols
			var x := (s - 0.5) * width
			# The sheet bellies out as it falls and bulges a little in the middle.
			var z := v + depth_swing * (noise.get_noise_2d(x * 1.4, t * 6.0) * 0.5 + t * 0.35) + 0.12 * t * t * sin(s * PI)
			line.append(Vector3(x, top * (1.0 - t) + 0.06, z))
		grid.append(line)
	for r in rows:
		for k in cols:
			var p00: Vector3 = grid[r][k]
			var p10: Vector3 = grid[r][k + 1]
			var p01: Vector3 = grid[r + 1][k]
			var p11: Vector3 = grid[r + 1][k + 1]
			for tri in [[p00, p10, p11, Vector2(float(k) / cols, top * r / rows), Vector2(float(k + 1) / cols, top * r / rows), Vector2(float(k + 1) / cols, top * (r + 1) / rows)],
					[p00, p11, p01, Vector2(float(k) / cols, top * r / rows), Vector2(float(k + 1) / cols, top * (r + 1) / rows), Vector2(float(k) / cols, top * (r + 1) / rows)]]:
				var n := (((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))).normalized()
				if n.z < 0.0:
					n = -n
				for j in 3:
					st.set_normal(n)
					st.set_uv(tri[3 + j])
					st.add_vertex(tri[j])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Lays the water on the rock: called once the mountains are built (see Outdoor), as it follows their surface.
func lay_water(lvl: Outdoor) -> void:
	# The stream on the cliff: from the crags down to the shelf's back edge, bending a little.
	var centre := []
	var widths := []
	var rock := []
	var v := STREAM_FROM_V
	while v <= SHELF_BACK_V:
		var t := (v - STREAM_FROM_V) / (SHELF_BACK_V - STREAM_FROM_V)
		centre.append(Vector3(sin(v * 0.42) * 0.55, 0.0, v))
		widths.append(lerpf(2.6, 4.3, t))
		rock.append(true)
		v += 0.5
	# Across the shelf's top to the brow.
	for k in 5:
		var t := k / 4.0
		var z := lerpf(SHELF_BACK_V + 0.4, BROW_V + 0.1, t)
		centre.append(Vector3(0, ROOF + 0.17, z))
		widths.append(CURTAIN_WIDTH - 0.3)
		rock.append(false)
	var length := 0.0
	for i in range(1, centre.size()):
		length += (centre[i] as Vector3).distance_to(centre[i - 1])
	# The first point on the rock is laid on its surface; the shelf points keep their own height.
	for i in centre.size():
		if rock[i]:
			var p: Vector3 = centre[i]
			var h := Mountains.surface_at(lvl, global_position.x + p.x, global_position.z + p.z)
			p.y = (h if h != INF else 3.0) + LIFT
			centre[i] = p
	# Keep the stream from dipping below the shelf where it joins it.
	var joined := false
	for i in centre.size():
		if not rock[i] and not joined:
			joined = true
		var p: Vector3 = centre[i]
		if i > 0 and not rock[i]:
			p.y = ROOF + 0.17
		centre[i] = p
	_ribbon(centre, widths, rock, _sheet_material(CURTAIN_WIDTH, length, 4.0))
	# The curtain, two layers a hand apart so it has some depth.
	var front := _sheet_material(CURTAIN_WIDTH, ROOF, -1.0)
	_curtain(CURTAIN_WIDTH, ROOF + 0.15, CURTAIN_V, 0.12, front)
	var back := _sheet_material(CURTAIN_WIDTH - 0.8, ROOF, -1.0)
	_curtain(CURTAIN_WIDTH - 0.8, ROOF + 0.1, CURTAIN_V - 0.22, 0.08, back)
	# The runnels either side, running down the rock into the pool.
	for side in [-1.0, 1.0]:
		var s: float = side
		var line := []
		var wide := []
		var on_rock := []
		var z := RUNNEL_FROM_V
		while z <= 2.6:
			var p := Vector3(s * (RUNNEL_U + sin(z * 0.6 + s) * 0.35), 0.0, z)
			var h := Mountains.surface_at(lvl, global_position.x + p.x, global_position.z + p.z)
			p.y = maxf(h if h != INF else 0.0, 0.0) + LIFT
			line.append(p)
			wide.append(RUNNEL_WIDTH + 0.5 * (z - RUNNEL_FROM_V) / 11.6)
			on_rock.append(true)
			z += 0.5
		var run_length := 0.0
		for i in range(1, line.size()):
			run_length += (line[i] as Vector3).distance_to(line[i - 1])
		_ribbon(line, wide, on_rock, _sheet_material(RUNNEL_WIDTH + 0.5, run_length, -1.0))
	# Spray: a cloud where the curtain lands, a thinner one at the runnels.
	var spray := _mist(CURTAIN_WIDTH, 30)
	spray.position = Vector3(0, 0.5, CURTAIN_V + 0.5)
	add_child(spray)
	_sprays.append(spray)
	for side in [-1.0, 1.0]:
		var s: float = side
		var puff := _mist(RUNNEL_WIDTH, 8)
		puff.position = Vector3(s * RUNNEL_U, 0.3, 3.0)
		add_child(puff)
		_sprays.append(puff)


static func _mist(width: float, count: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Spray"
	p.amount = count
	p.lifetime = 2.6
	p.local_coords = true
	p.mesh = Effects._quad(1.5, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.45, 0.15, 0.3)
	p.direction = Vector3(0, 1, 0.7)
	p.spread = 28.0
	p.gravity = Vector3(0, 0.12, 0.2)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.damping_min = 0.2
	p.damping_max = 0.4
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(0.5, 1.2))
	grow.add_point(Vector2(1, 2.0))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	var white := Color(0.85, 0.93, 1.0)
	ramp.set_color(0, Color(white, 0.0))
	ramp.add_point(0.15, Color(white, 0.2))
	ramp.add_point(0.6, Color(white, 0.1))
	ramp.set_color(ramp.get_point_count() - 1, Color(white, 0.0))
	p.color_ramp = ramp
	Effects.start_cold(p)
	p.emitting = true
	return p


# --- Winter ------------------------------------------------------------------

static func _ice_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.88, 0.98, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(0.25, 0.45, 0.6)
	m.emission_energy_multiplier = 0.25
	return m


## Icicles hanging from the brow and the shelf, and the mound of ice where the curtain lands.
func _ice(rng: RandomNumberGenerator) -> void:
	var b := W.Builder.new()
	var count := 30
	for i in count:
		var u := lerpf(-CURTAIN_WIDTH * 0.5 - 0.2, CURTAIN_WIDTH * 0.5 + 0.2, (i + rng.randf_range(-0.3, 0.3)) / (count - 1))
		var len := rng.randf_range(0.35, 1.5) * (1.0 - 0.45 * absf(u) / (CURTAIN_WIDTH * 0.5 + 0.2))
		var r := rng.randf_range(0.05, 0.11)
		b.cylinder(Vector3(u, ROOF - 0.15 - len, CURTAIN_V + rng.randf_range(-0.12, 0.2)), 0.004, r, len, Color(0.8, 0.92, 1.0), W.IRON, 7)
	for side in [-1.0, 1.0]:
		var s: float = side
		for i in 5:
			var len := rng.randf_range(0.3, 0.9)
			b.cylinder(Vector3(s * (CURTAIN_WIDTH * 0.5 + 0.4 + i * 0.28), ROOF - 0.5 - len - 0.1 * i, BROW_V + rng.randf_range(-0.2, 0.2)), 0.004, 0.07, len, Color(0.8, 0.92, 1.0), W.IRON, 7)
	var mi := b.finish(_icicles, Vector3.ZERO, false)
	mi.material_override = _ice_material()
	add_child(_icicles)
	# The icicles grow downwards from the brow: scale about the brow's height.
	_icicles.position = Vector3(0, ROOF, 0)
	mi.position = Vector3(0, -ROOF, 0)
	_icicles.visible = false
	# The ice at the foot: lumps heaped where the spray froze.
	for i in 9:
		var u := rng.randf_range(-2.4, 2.4)
		var lump := _rock(Vector3(u, 0.15, CURTAIN_V + 0.55 + rng.randf_range(-0.2, 0.5)), Vector3(rng.randf_range(0.5, 1.0), rng.randf_range(0.35, 0.7), rng.randf_range(0.4, 0.7)), rng, _ice_foot, _ice_material(), Color(0.85, 0.95, 1.0))
		lump.material_override = _ice_material()
	add_child(_ice_foot)
	_ice_foot.visible = false


## Snow in pads on the shelf and the boulders.
func _snow(rng: RandomNumberGenerator) -> void:
	var white := Color(0.93, 0.95, 0.99)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = white
	mat.roughness = 0.95
	var pads := [Vector3(-0.8, ROOF + 0.05, -3.4), Vector3(1.0, ROOF + 0.05, -3.0), Vector3(-2.9, 4.0 * K + 0.5, -1.3), Vector3(2.9, 4.0 * K + 0.5, -1.3),
			Vector3(-2.6, 2.8 * K, -1.6), Vector3(2.6, 2.8 * K, -1.6), Vector3(-4.0, 2.2 * K, -1.8), Vector3(4.0, 2.2 * K, -1.8), Vector3(-0.2, ROOF + 0.05, -1.6)]
	for p: Vector3 in pads:
		var pad := _rock(p, Vector3(rng.randf_range(0.9, 1.5), 0.3, rng.randf_range(0.9, 1.4)), rng, _snow_caps, mat, white)
		pad.material_override = mat
	add_child(_snow_caps)
	_snow_caps.visible = false

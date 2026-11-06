class_name Puddles
extends Node3D
## Rain puddles in the open air. While it rains (or storms), puddles of
## see-through water fill up all over the open ground (see puddle.gdshader):
## big ones in the dips of the grass and the square, long ones in the ruts of
## the dirt paths, and small ones along the walls of the houses where the
## rain runs off the roofs. When the rain stops they stay a while and then
## dry up, the small ones first. A hero who walks or runs through one
## splashes with every step (see Player._footsteps and splash).
##
## How much water lies about is kept by the game, since the rain falls on
## while the hero is down in the dungeon too (see Weather.puddle_water); the
## puddles only show it. The dips come from a seed of the map, so the
## puddles form in the same places every time it rains.

## The ground they form on: grass, dirt path, the square.
const GROUND := ".,:"
## The dirt paths, where cart ruts and footprints hold the water.
const PATH := ","
## Water that is there already (ponds, the well, the fountain, holes): no
## puddle runs into it.
const WET := "~;(>qF"
## One puddle for about this many tiles of open ground, at most MAX.
const TILES_PER_PUDDLE := 3.5
const MAX := 480
## A puddle's radius in metres (a tile is 4 m), smallest and largest, and
## the largest beside a wall, a fence or a house, so it stays on its tile.
const RADIUS := Vector2(0.55, 1.85)
const EDGE_RADIUS := 1.0
## How much further a long puddle in a rut reaches (of its radius).
const LONG_REACH := 1.5
## How far apart two puddles stay, as a share of their radii added up.
const APART := 1.25
## How big a dip in the ground is (metres across, roughly).
const DIP_SIZE := 22.0
## Just above the ground and the paving, so nothing flickers through.
const LIFT := 0.035
## The wet soil reaches this far past the water's edge (of the radius).
const SOIL := 0.28
## How deep a puddle has to be (of its full size) to splash in.
const SPLASH_FILL := 0.2
## How far the water has to rise or sink before the puddles grow or shrink.
const WATER_STEP := 0.004
## How long the waves of a step run over the water (seconds), and how many
## steps can send waves at once (see puddle.gdshader).
const STEP_WAVE := 1.2
const STEP_WAVES := 3
## How many shapes the puddles share (round ones and long ones for the
## ruts); each puddle turns and sizes one of them.
const SHAPES := 16

const SHADER := preload("res://shaders/puddle.gdshader")

## Each puddle: its node, centre, full radius, the water level (0 to 1) it
## needs before it starts to fill, and how full it is now.
var spots: Array[Dictionary] = []
var water := 0.0
## The water level the puddles show now (see set_water).
var _shown := -1.0
var _material: ShaderMaterial
## The last steps into the puddles: where, and how long ago (w).
var _steps: Array[Vector4] = []
## Which puddles reach into each tile, for finding the one underfoot fast.
var _by_tile := {}
static var _drop_mesh: SphereMesh
## The shared shapes, of radius 1: round ones, then long ones.
static var _round: Array[ArrayMesh] = []
static var _long: Array[ArrayMesh] = []


## Finds the dips on `level`'s open ground and lays a puddle in each, dry to
## begin with.
func _init(level: Level, seed_value: int) -> void:
	name = "Puddles"
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	for i in STEP_WAVES:
		_steps.append(Vector4(0, 0, 0, -1.0))
	_material.set_shader_parameter("steps", _steps)
	set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_make_shapes()
	var dips := FastNoiseLite.new()
	dips.seed = seed_value
	dips.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	dips.frequency = 1.0 / DIP_SIZE
	dips.fractal_octaves = 2
	# Every tile of open ground, ranked by how much water it would hold: the
	# low ground first, the paths and the eaves of the houses before the
	# open grass, with a little chance mixed in.
	var ranked: Array = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if not GROUND.contains(level.cell_char(c)) or _beside(level, c, WET):
				continue
			var at := level.cell_to_world(c)
			var depth := 0.5 - 0.5 * dips.get_noise_2d(at.x, at.z)
			var score := depth + rng.randf() * 0.6
			if level.cell_char(c) == PATH:
				score += 0.3
			if _beside(level, c, Outdoor.BLOCK_CHARS):
				score += 0.2
			ranked.append([score, c, depth])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and (a[1].y < b[1].y or (a[1].y == b[1].y and a[1].x < b[1].x))))
	var want := mini(MAX, roundi(ranked.size() / TILES_PER_PUDDLE))
	for entry: Array in ranked:
		if spots.size() >= want:
			break
		var c: Vector2i = entry[1]
		var depth: float = entry[2]
		# Deep dips hold big puddles, the rest small ones.
		var radius := lerpf(RADIUS.x, RADIUS.y, clampf(depth * depth * 1.4 + rng.randf_range(-0.3, 0.2), 0.0, 1.0))
		var away := _away_from_walls(level, c)
		var shift := Vector2(rng.randf_range(-1.1, 1.1), rng.randf_range(-1.1, 1.1))
		if away != Vector2.INF:
			# Beside a wall: a small one, pushed out from under the eaves.
			radius = minf(radius, EDGE_RADIUS * rng.randf_range(0.6, 1.0))
			shift = away * 0.45
		var at := level.cell_to_world(c) + Vector3(shift.x, LIFT, shift.y)
		var long := level.cell_char(c) == PATH
		# How far it reaches, for keeping the next one clear of it.
		var span := radius * (LONG_REACH if long else 1.0)
		if _crowded(at, span):
			continue
		var turn := rng.randf() * TAU
		if long:
			# Along the path, as a rut runs.
			var along_x := PATH.contains(level.cell_char(c + Vector2i.LEFT)) or PATH.contains(level.cell_char(c + Vector2i.RIGHT))
			var along_z := PATH.contains(level.cell_char(c + Vector2i.UP)) or PATH.contains(level.cell_char(c + Vector2i.DOWN))
			if along_x != along_z:
				turn = (0.0 if along_x else PI / 2.0) + rng.randf_range(-0.2, 0.2) + (PI if rng.randf() < 0.5 else 0.0)
		var shapes := _long if long else _round
		var mi := MeshInstance3D.new()
		mi.mesh = shapes[rng.randi() % shapes.size()]
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = at
		mi.rotation.y = turn
		mi.scale = Vector3(radius, 0.01, radius)
		mi.visible = false
		add_child(mi)
		# Big puddles fill first and dry last; small ones need more rain.
		var needs := remap(radius, RADIUS.x, RADIUS.y, 0.45, 0.0) + rng.randf_range(0.0, 0.06)
		var s := {"node": mi, "at": at, "radius": radius, "needs": needs, "fill": 0.0, "span": span}
		spots.append(s)
		for t in _tiles_under(at, span):
			if not _by_tile.has(t):
				_by_tile[t] = []
			_by_tile[t].append(s)


## Whether any of the eight tiles round `c` is one of `chars`.
static func _beside(level: Level, c: Vector2i, chars: String) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and chars.contains(level.cell_char(c + Vector2i(dx, dy))):
				return true
	return false


## Which way (on the ground) leads away from the walls, fences and houses
## round `c`, or Vector2.INF when there is open ground all round.
static func _away_from_walls(level: Level, c: Vector2i) -> Vector2:
	var away := Vector2.ZERO
	var walled := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and not GROUND.contains(level.cell_char(c + Vector2i(dx, dy))):
				walled = true
				away -= Vector2(dx, dy)
	if not walled:
		return Vector2.INF
	return away.normalized() if away.length_squared() > 0.01 else Vector2.ZERO


## Whether a puddle reaching `span` round `at` would run into one already
## laid.
func _crowded(at: Vector3, span: float) -> bool:
	for t in _tiles_under(at, (span + RADIUS.y * LONG_REACH) * APART):
		for s: Dictionary in _by_tile.get(t, []):
			var d := Vector2(at.x - s.at.x, at.z - s.at.z)
			var room := (span + float(s.span)) * APART
			if d.length_squared() < room * room:
				return true
	return false


## The tiles a circle of `reach` round `at` touches.
static func _tiles_under(at: Vector3, reach: float) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var lo := Vector2i(floori((at.x - reach) / Level.TILE), floori((at.z - reach) / Level.TILE))
	var hi := Vector2i(floori((at.x + reach) / Level.TILE), floori((at.z + reach) / Level.TILE))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			tiles.append(Vector2i(x, y))
	return tiles


## The shapes the puddles share, made once.
static func _make_shapes() -> void:
	if not _round.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	for i in SHAPES:
		var long := i >= SHAPES * 5 / 8
		var stretch := Vector2(rng.randf_range(1.5, 1.9), rng.randf_range(0.55, 0.7)) if long \
				else Vector2(rng.randf_range(1.0, 1.45), rng.randf_range(0.75, 1.0))
		(_long if long else _round).append(_shape(rng, stretch))


## Shows `level` of water (0 to 1): each puddle fills or shrinks with it.
## `rain` (0 to 1) rings the water with falling drops, and `sky` (0 to 1)
## is how bright the sky is that the water mirrors.
func set_water(level: float, rain := 0.0, sky := 1.0) -> void:
	water = clampf(level, 0.0, 1.0)
	_material.set_shader_parameter("rain", clampf(rain, 0.0, 1.0))
	_material.set_shader_parameter("sky", clampf(sky, 0.0, 1.0))
	# The water rises and sinks slowly: the puddles follow it in small steps,
	# not every frame.
	if water == _shown or (absf(water - _shown) < WATER_STEP and water > 0.0 and water < 1.0):
		return
	_shown = water
	for s in spots:
		var fill := clampf((water - float(s.needs)) / (1.0 - float(s.needs)), 0.0, 1.0)
		s.fill = fill
		var mi: MeshInstance3D = s.node
		mi.visible = fill > 0.01
		if mi.visible:
			# It shrinks towards its deepest point as it dries.
			var size := (0.3 + 0.7 * sqrt(fill)) * float(s.radius)
			# The height of the scale tells the shader how full it is.
			mi.scale = Vector3(size, fill, size)


## The puddle a spot on the ground stands in, or {} for dry ground.
func puddle_at(p: Vector3) -> Dictionary:
	var tile := Vector2i(floori(p.x / Level.TILE), floori(p.z / Level.TILE))
	for s: Dictionary in _by_tile.get(tile, []):
		if float(s.fill) < SPLASH_FILL:
			continue
		var reach: float = float(s.radius) * (0.3 + 0.7 * sqrt(float(s.fill))) * 0.85
		var d := Vector2(p.x - s.at.x, p.z - s.at.z)
		if d.length_squared() < reach * reach:
			return s
	return {}


## Whether a spot on the ground is in a puddle deep enough to splash.
func wet_at(p: Vector3) -> bool:
	return not puddle_at(p).is_empty()


## The waves of the last steps run on.
func _process(delta: float) -> void:
	var running := false
	for i in _steps.size():
		if _steps[i].w >= 0.0:
			_steps[i].w += delta
			if _steps[i].w > STEP_WAVE:
				_steps[i].w = -1.0
			else:
				running = true
	_material.set_shader_parameter("steps", _steps)
	set_process(running)


## A splash where a foot lands in a puddle: a spray of drops thrown up and
## a ring of waves running out over the water; a soft one for a sneaking
## step.
func splash(at: Vector3, hard := true) -> void:
	if not is_inside_tree():
		return
	# The new step's waves take the place of the oldest.
	var oldest := 0
	for i in _steps.size():
		if _steps[i].w < 0.0 or _steps[i].w > _steps[oldest].w:
			oldest = i
			if _steps[i].w < 0.0:
				break
	_steps[oldest] = Vector4(at.x, at.y, at.z, 0.0)
	_material.set_shader_parameter("steps", _steps)
	set_process(true)
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.08
		_drop_mesh.height = 0.16
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.9, 0.95, 0.8)
		# Unlit, so the spray reads against the dark water by day and night.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_drop_mesh.material = mat
	var drops := CPUParticles3D.new()
	drops.mesh = _drop_mesh
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.amount = 18 if hard else 7
	drops.lifetime = 0.6
	drops.direction = Vector3.UP
	drops.spread = 70.0
	drops.initial_velocity_min = 2.0 if hard else 0.9
	drops.initial_velocity_max = 3.6 if hard else 1.6
	drops.gravity = Vector3(0, -14.0, 0)
	drops.scale_amount_min = 0.5
	drops.scale_amount_max = 1.2
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.25
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drops)
	drops.global_position = Vector3(at.x, LIFT + 0.03, at.z)
	drops.finished.connect(drops.queue_free)
	drops.emitting = true


## One puddle: a ragged, lobed ring of wet soil round a pool of water that
## is deepest in the middle. One fan, so no part of it is drawn twice (the
## water is see-through). COLOR.r runs from 0 at the soil's outer edge to 1
## in the middle (see puddle.gdshader).
static func _shape(rng: RandomNumberGenerator, stretch: Vector2, radius := 1.0) -> ArrayMesh:
	var sides := 40
	var waves: Array = []
	for w in 4:
		waves.append([rng.randi_range(1, 4), rng.randf() * TAU, rng.randf_range(0.25, 1.0)])
	# Rings from the outside in: soil edge, water's edge, the shallows, the middle.
	var rings := [[1.0 + SOIL, 0.0], [1.0, 0.3], [0.55, 0.75]]
	var points: Array = []
	for ring: Array in rings:
		var row: Array[Vector3] = []
		for s in sides:
			var a := TAU * s / sides
			var wobble := 0.0
			for w: Array in waves:
				wobble += sin(a * w[0] + w[1]) * w[2]
			var d := radius * (1.0 + wobble * 0.11) * float(ring[0])
			var p := Vector2.from_angle(a) * d * stretch
			row.append(Vector3(p.x, 0.0, p.y))
		points.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings.size() - 1:
		var outer: Array[Vector3] = points[r]
		var inner: Array[Vector3] = points[r + 1]
		var co := float(rings[r][1])
		var ci := float(rings[r + 1][1])
		for s in sides:
			var n := (s + 1) % sides
			_vertex(st, inner[s], ci)
			_vertex(st, outer[s], co)
			_vertex(st, outer[n], co)
			_vertex(st, inner[s], ci)
			_vertex(st, outer[n], co)
			_vertex(st, inner[n], ci)
	var last: Array[Vector3] = points[rings.size() - 1]
	var cl := float(rings[rings.size() - 1][1])
	for s in sides:
		_vertex(st, Vector3.ZERO, 1.0)
		_vertex(st, last[s], cl)
		_vertex(st, last[(s + 1) % sides], cl)
	return st.commit()


static func _vertex(st: SurfaceTool, p: Vector3, inner: float) -> void:
	st.set_color(Color(inner, 0, 0))
	st.set_normal(Vector3.UP)
	st.add_vertex(p)

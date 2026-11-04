class_name Puddles
extends Node3D
## Rain puddles in the open air. While it rains (or storms), large puddles
## of see-through water fill up in the hollows of the grass, the paths and
## the square (see puddle.gdshader); when the rain stops they stay a while
## and then dry up, the small ones first. A hero who walks or runs through
## one splashes with every step (see Player._footsteps and splash).
##
## How much water lies about is kept by the game, since the rain falls on
## while the hero is down in the dungeon too (see Weather.puddle_water); the
## puddles only show it. The hollows come from a seed of the map, so the
## puddles form in the same places every time it rains.

## The ground they form on: grass, dirt path, the square.
const GROUND := ".,:"
## One puddle for about this many tiles of open ground, at most MAX.
const TILES_PER_PUDDLE := 18
const MAX := 90
## How far (in tiles) two puddles stay apart.
const APART := 2
## A puddle's radius in metres (a tile is 4 m), smallest and largest.
const RADIUS := Vector2(1.0, 1.85)
## Just above the ground and the paving, so nothing flickers through.
const LIFT := 0.035
## The wet soil reaches this far past the water's edge (of the radius).
const SOIL := 0.28
## How deep a puddle has to be (of its full size) to splash in.
const SPLASH_FILL := 0.2
## How long the waves of a step run over the water (seconds), and how many
## steps can send waves at once (see puddle.gdshader).
const STEP_WAVE := 1.2
const STEP_WAVES := 3

const SHADER := preload("res://shaders/puddle.gdshader")

## Each puddle: its node, centre, full radius, the water level (0 to 1) it
## needs before it starts to fill, and how full it is now.
var spots: Array[Dictionary] = []
var water := 0.0
var _material: ShaderMaterial
## The last steps into the puddles: where, and how long ago (w).
var _steps: Array[Vector4] = []
static var _drop_mesh: SphereMesh


## Picks the hollows on `level`'s open ground and lays a puddle in each,
## dry to begin with.
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
	var cells: Array[Vector2i] = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if _hollow(level, c):
				cells.append(c)
	# A shuffle of our own, so the same map always gets the same puddles.
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	var want := mini(MAX, cells.size() / TILES_PER_PUDDLE)
	var picked: Array[Vector2i] = []
	for c in cells:
		if picked.size() >= want:
			break
		if picked.any(func(p: Vector2i) -> bool: return maxi(absi(p.x - c.x), absi(p.y - c.y)) < APART):
			continue
		picked.append(c)
	for c in picked:
		var radius := rng.randf_range(RADIUS.x, RADIUS.y)
		var at := level.cell_to_world(c) + Vector3(rng.randf_range(-0.6, 0.6), LIFT, rng.randf_range(-0.6, 0.6))
		var mi := MeshInstance3D.new()
		mi.mesh = _shape(rng, radius)
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = at
		mi.rotation.y = rng.randf() * TAU
		mi.visible = false
		add_child(mi)
		# Big puddles fill first and dry last; small ones need more rain.
		var needs := remap(radius, RADIUS.x, RADIUS.y, 0.45, 0.0) + rng.randf_range(0.0, 0.1)
		spots.append({"node": mi, "at": at, "radius": radius, "needs": needs, "fill": 0.0})


## Open ground with open ground all round, so no puddle runs under a wall,
## a fence or a house.
static func _hollow(level: Level, c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not GROUND.contains(level.cell_char(c + Vector2i(dx, dy))):
				return false
	return true


## Shows `level` of water (0 to 1): each puddle fills or shrinks with it.
## `rain` (0 to 1) rings the water with falling drops, and `sky` (0 to 1)
## is how bright the sky is that the water mirrors.
func set_water(level: float, rain := 0.0, sky := 1.0) -> void:
	water = clampf(level, 0.0, 1.0)
	_material.set_shader_parameter("rain", clampf(rain, 0.0, 1.0))
	_material.set_shader_parameter("sky", clampf(sky, 0.0, 1.0))
	for s in spots:
		var fill := clampf((water - float(s.needs)) / (1.0 - float(s.needs)), 0.0, 1.0)
		s.fill = fill
		var mi: MeshInstance3D = s.node
		mi.visible = fill > 0.01
		if mi.visible:
			# It shrinks towards its deepest point as it dries.
			var size := 0.3 + 0.7 * sqrt(fill)
			mi.scale = Vector3(size, 1.0, size)
			mi.set_instance_shader_parameter("fill", fill)


## The puddle a spot on the ground stands in, or {} for dry ground.
func puddle_at(p: Vector3) -> Dictionary:
	for s in spots:
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
static func _shape(rng: RandomNumberGenerator, radius: float) -> ArrayMesh:
	var sides := 40
	var waves: Array = []
	for w in 4:
		waves.append([rng.randi_range(1, 4), rng.randf() * TAU, rng.randf_range(0.25, 1.0)])
	var stretch := Vector2(rng.randf_range(1.0, 1.45), rng.randf_range(0.75, 1.0))
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

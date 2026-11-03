class_name VillageBirds
extends Node3D
## The birds that nest on the village roofs (see AgedStone): by day each one
## flies back and forth between its nest and the village around it, now to
## the ground to peck about for a while, now over to another nest or a loop
## round the roofs, and home again. At night they sit in their nests.
##
## All of them are one MultiMesh, their wings beating in the vertex shader
## (shaders/bird.gdshader), so they cost one draw and a few lines a frame.
## They only fly while the hero is near enough to see them.

const SHADER := preload("res://shaders/bird.gdshader")
## Birds per nest, flying speed (metres a second), how far they fly from
## the nest at most, and the seconds they sit or peck before flying again.
const PER_NEST := 2
const SPEED := 7.5
const RANGE := 34.0
const SIT := Vector2(2.5, 7.0)
const PECK := Vector2(3.0, 8.0)
## Beyond this distance from the hero (metres) the birds keep still.
const AWAKE_RANGE := 90.0
const SIZE := 1.5

## Each bird: {"home", "at", "from", "to", "lift", "t", "time", "wait",
## "state" ("sit", "fly", "peck"), "phase", "yaw"}.
var birds: Array = []
var nests: Array[Vector3] = []
## Spots on the ground where the birds land to peck.
var ground: Array[Vector3] = []
var level: Node3D
var _mm: MultiMesh
var _rng := RandomNumberGenerator.new()


func _init(level_node: Node3D, nest_spots: Array[Vector3], ground_spots: Array[Vector3], seed_value: int) -> void:
	name = "VillageBirds"
	level = level_node
	nests = nest_spots
	ground = ground_spots
	_rng.seed = seed_value
	for nest in nests:
		for i in PER_NEST:
			var perch := nest + Vector3(0.18 * (i * 2 - 1), 0.22, 0.05)
			birds.append({"home": perch, "at": perch, "from": perch, "to": perch, "lift": 0.0, "t": 0.0,
					"time": 1.0, "wait": _rng.randf_range(0.5, SIT.y), "state": "sit",
					"phase": _rng.randf() * TAU, "yaw": _rng.randf() * TAU, "next": "out"})
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = bird_mesh()
	_mm.instance_count = birds.size()
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	node.material_override = mat
	add_child(node)
	for i in birds.size():
		_show(i)


func _process(delta: float) -> void:
	var hero: Node3D = level.get("player")
	if hero and not birds.is_empty():
		var near := false
		for nest in nests:
			if nest.distance_to(hero.global_position) < AWAKE_RANGE:
				near = true
				break
		if not near:
			return
	var night: bool = level.get("night") == true
	for i in birds.size():
		_think(birds[i], delta, night)
		_show(i)


func _think(b: Dictionary, delta: float, night: bool) -> void:
	match b.state:
		"fly":
			b.t += delta / b.time
			if b.t >= 1.0:
				b.at = b.to
				if b.to == b.home:
					b.state = "sit"
					b.wait = _rng.randf_range(SIT.x, SIT.y)
				elif b.next == "peck":
					b.state = "peck"
					b.wait = _rng.randf_range(PECK.x, PECK.y)
				else:
					b.state = "sit"
					b.wait = _rng.randf_range(SIT.x, SIT.y) * 0.6
				return
			var t: float = b.t
			var from: Vector3 = b.from
			var to: Vector3 = b.to
			var lift := Vector3.UP * float(b.lift)
			var mid := (from + to) * 0.5 + lift
			var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			var dir := p - (b.at as Vector3)
			if dir.length() > 0.001:
				b.yaw = atan2(dir.x, dir.z)
			b.at = p
		"peck":
			b.wait -= delta
			# Little hops about on the ground.
			if _rng.randf() < delta * 1.2:
				b.at += Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
				b.yaw = _rng.randf() * TAU
			if b.wait <= 0.0 or night:
				_fly(b, b.home, "home")
		"sit":
			b.wait -= delta
			if night:
				if b.at != b.home:
					_fly(b, b.home, "home")
				return
			if b.wait > 0.0:
				return
			if b.at != b.home:
				_fly(b, b.home, "home")
				return
			var roll := _rng.randf()
			var near_ground := ground.filter(func(g: Vector3): return g.distance_to(b.home) < RANGE)
			if roll < 0.55 and not near_ground.is_empty():
				var spot: Vector3 = near_ground[_rng.randi() % near_ground.size()]
				_fly(b, spot + Vector3(_rng.randf_range(-1.5, 1.5), 0.05, _rng.randf_range(-1.5, 1.5)), "peck")
			elif roll < 0.8 and nests.size() > 1:
				var other: Vector3 = nests[_rng.randi() % nests.size()]
				if other.distance_to(b.home) < RANGE * 1.5 and other.distance_to(b.home) > 1.0:
					_fly(b, other + Vector3(_rng.randf_range(-0.3, 0.3), 0.3, _rng.randf_range(-0.3, 0.3)), "sit")
				else:
					b.wait = _rng.randf_range(SIT.x, SIT.y)
			else:
				# A loop round the roofs, back to the nest.
				var away := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(8.0, 16.0)
				_fly(b, b.home + away + Vector3.UP * _rng.randf_range(1.0, 4.0), "sit")
				b.wait = 0.0


func _fly(b: Dictionary, to: Vector3, next: String) -> void:
	b.from = b.at
	b.to = to
	b.next = next
	b.t = 0.0
	var dist := (b.from as Vector3).distance_to(to)
	b.time = maxf(0.6, dist / SPEED)
	b.lift = 2.0 + dist * 0.25
	b.state = "fly"


func _show(i: int) -> void:
	var b: Dictionary = birds[i]
	var flying: bool = b.state == "fly"
	var basis := Basis(Vector3.UP, b.yaw).scaled(Vector3.ONE * SIZE)
	var at: Vector3 = b.at
	if flying:
		# Gliding down the last stretch, beating hard on the way up.
		var climbing: bool = b.t < 0.5
		_mm.set_instance_custom_data(i, Color(b.phase, 0.9 if climbing else 0.45, 0.0, 0.0))
		basis = basis * Basis(Vector3.RIGHT, -0.25 if climbing else 0.15)
	else:
		_mm.set_instance_custom_data(i, Color(b.phase, 0.0, 1.0, 0.0))
	_mm.set_instance_transform(i, Transform3D(basis, at))


## A small dark bird: a body, a head, a tail and two wings, flying towards
## +z. COLOR.a marks the wings for the shader (see bird.gdshader).
static func bird_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := Color(0.18, 0.15, 0.13, 0.5)
	var belly := Color(0.45, 0.38, 0.3, 0.5)
	# Body: a stretched diamond.
	var nose := Vector3(0, 0.02, 0.2)
	var tail := Vector3(0, 0.03, -0.14)
	var top := Vector3(0, 0.08, 0.02)
	var bottom := Vector3(0, -0.05, 0.02)
	var left := Vector3(-0.055, 0.02, 0.02)
	var right := Vector3(0.055, 0.02, 0.02)
	for tri: Array in [[nose, top, right], [nose, right, bottom], [nose, bottom, left], [nose, left, top],
			[tail, right, top], [tail, bottom, right], [tail, left, bottom], [tail, top, left]]:
		for p: Vector3 in tri:
			st.set_color(belly if p == bottom else body)
			st.add_vertex(p)
	# The tail fan.
	for p: Vector3 in [Vector3(0, 0.04, -0.1), Vector3(-0.06, 0.03, -0.24), Vector3(0.06, 0.03, -0.24)]:
		st.set_color(body)
		st.add_vertex(p)
	# Wings: a swept triangle on each side, the tip marked by COLOR.a.
	for side: float in [-1.0, 1.0]:
		var tip_a := 0.5 + side * 0.5
		var root_a := 0.5 + side * 0.04
		var pts := [Vector3(side * 0.04, 0.04, 0.08), Vector3(side * 0.04, 0.04, -0.04), Vector3(side * 0.3, 0.05, -0.08)]
		var alphas := [root_a, root_a, tip_a]
		var inner := [Vector3(side * 0.04, 0.04, 0.08), Vector3(side * 0.3, 0.05, -0.08), Vector3(side * 0.18, 0.045, 0.06)]
		var inner_a := [root_a, tip_a, 0.5 + side * 0.3]
		for k in 3:
			st.set_color(Color(body.r, body.g, body.b, alphas[k]))
			st.add_vertex(pts[k])
		for k in 3:
			st.set_color(Color(body.r, body.g, body.b, inner_a[k]))
			st.add_vertex(inner[k])
	st.generate_normals()
	return st.commit()

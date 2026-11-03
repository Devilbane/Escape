class_name BloodStains
extends RefCounted
## Blood on the floor round spikes: a few pools with ragged, lobed edges,
## smears, and a spatter of drops flung out from them, some in thin trails.
## Everything of one spot is one flat mesh, so a hall full of spikes stays
## cheap. The shapes come from a seed, so a spot looks the same each visit,
## and no two spots look alike.

## Fresh blood in the middle of a pool, older, browner blood at its rim.
const WET := Color(0.4, 0.02, 0.018)
const DRY := Color(0.24, 0.035, 0.022)

static var _material: StandardMaterial3D


## Lays blood round `center` (on the floor, in `parent`'s space) under a new
## node in `parent`, and returns that node. `spread` is how far (metres) the
## pools reach from the centre; the drops fly a little further.
static func lay(parent: Node3D, center: Vector3, seed_value: int, pools := 3, drops := 26, spread := 1.6) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layer := 0
	var spots: Array[Vector2] = []
	for i in pools:
		var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, spread)
		spots.append(at)
		var r := rng.randf_range(0.35, 0.8)
		_blob(st, rng, at, r, layer, 22, 0.35)
		layer += 1
		# A lobe or two run off the pool, as if it had spread over the stones.
		for k in rng.randi_range(1, 3):
			var dir := Vector2.from_angle(rng.randf() * TAU)
			_blob(st, rng, at + dir * r * rng.randf_range(0.6, 1.0), r * rng.randf_range(0.3, 0.55), layer, 14, 0.3)
			layer += 1
	# A smear or two: long, thin streaks dragged out of a pool.
	for i in rng.randi_range(1, 2):
		var from: Vector2 = spots[rng.randi() % spots.size()]
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var length := rng.randf_range(0.6, 1.3)
		for k in 6:
			var f := k / 5.0
			_blob(st, rng, from + dir * length * f, lerpf(0.22, 0.06, f), layer, 10, 0.2)
		layer += 1
	# Drops: flung from the pools, smaller the further they flew, and some
	# strung out in a line.
	for i in drops:
		var from: Vector2 = spots[rng.randi() % spots.size()]
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var far := rng.randf_range(0.6, spread + 0.9)
		var r := lerpf(0.11, 0.035, clampf(far / (spread + 0.9), 0.0, 1.0)) * rng.randf_range(0.7, 1.3)
		_blob(st, rng, from + dir * far, r, layer, 8, 0.25)
		if rng.randf() < 0.3:
			for k in rng.randi_range(2, 4):
				far += r * rng.randf_range(2.0, 3.5)
				r *= 0.75
				_blob(st, rng, from + dir * far, r, layer, 7, 0.2)
	layer += 1
	var mi := MeshInstance3D.new()
	mi.name = "Blood"
	mi.mesh = st.commit()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center
	parent.add_child(mi)
	return mi


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.32
		_material.metallic_specular = 0.5
	return _material


## One flat, ragged blob: a fan whose rim wobbles by `rough` of its radius.
static func _blob(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector2, r: float, layer: int, sides: int, rough: float) -> void:
	var y := layer * 0.0007
	var waves: Array = []
	for w in 3:
		waves.append([rng.randi_range(2, 5), rng.randf() * TAU, rng.randf_range(0.3, 1.0)])
	var stretch := Vector2(rng.randf_range(0.8, 1.25), rng.randf_range(0.8, 1.25))
	var turn := rng.randf() * TAU
	var rim: Array[Vector3] = []
	for s in sides:
		var a := TAU * s / sides
		var wobble := 0.0
		for w: Array in waves:
			wobble += sin(a * w[0] + w[1]) * w[2]
		var d := r * (1.0 + wobble / 3.0 * rough + rng.randf_range(-0.08, 0.08))
		var p := (Vector2.from_angle(a) * d * stretch).rotated(turn)
		rim.append(Vector3(at.x + p.x, y, at.y + p.y))
	var mid := Vector3(at.x, y, at.y)
	for s in sides:
		var a := rim[s]
		var b := rim[(s + 1) % sides]
		_vertex(st, mid, WET)
		_vertex(st, a, DRY)
		_vertex(st, b, DRY)


static func _vertex(st: SurfaceTool, p: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(Vector3.UP)
	st.add_vertex(p)

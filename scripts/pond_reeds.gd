class_name PondReeds
extends RefCounted
## Reeds and cattails along the bank of the village ponds, so the water looks like a real pond
## and not a cut-out. They stand on the open ground just outside the water (never on the pond
## tiles, which turn into ice walkable in winter) and keep their straw colour all year; snow
## wear caps of snow while snow lies (see set_snow), growing with the snow and melting with it.
## Here and there a few rounded stones lie at the water's edge, some half sunk in the shallows.

## The caps of snow on the cattail heads and the tips of the stems, or null without reeds.
var snow_caps: MultiMeshInstance3D
var _full: Array[Transform3D] = []


## Clumps per metre of bank.
const CLUMPS_PER_METRE := 0.5
const STEMS := 5

## Grows the reeds round every pond tile in `ponds` (see Outdoor._pond_waters) in `level`.
static func grow(level: Outdoor, ponds: Array) -> PondReeds:
	var reeds := PondReeds.new()
	var water := {}
	for w: Dictionary in ponds:
		water[w.cell] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.level_name + "schilf")
	var stems: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var half := Level.TILE * 0.5
	for w: Dictionary in ponds:
		var cell: Vector2i = w.cell
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + dir
			if water.has(next) or not level.is_open(next) or level.cell_char(next) != ".":
				continue
			var along := Vector3(dir.y, 0, dir.x)
			# Stones on about half the stretches of bank, in twos and threes.
			if rng.randf() < 0.5:
				var lump: Vector3 = w.pos + Vector3(dir.x, 0, dir.y) * (half + rng.randf_range(-0.4, 0.3)) \
						+ along * rng.randf_range(-half * 0.8, half * 0.8)
				for k in rng.randi_range(1, 3):
					var size := rng.randf_range(0.12, 0.34)
					var p := lump + Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
					var turn := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
					var shape := turn.scaled(Vector3(size * rng.randf_range(1.0, 1.5), size * rng.randf_range(0.45, 0.7), size))
					stones.append(Transform3D(shape, p + Vector3(0, size * 0.12, 0)))
			var count := int(Level.TILE * CLUMPS_PER_METRE * rng.randf_range(0.6, 1.4))
			for i in count:
				# Hugging the water's edge, a little outside it, spread along the bank.
				var at: Vector3 = w.pos + Vector3(dir.x, 0, dir.y) * (half + rng.randf_range(-0.15, 0.7)) \
						+ along * rng.randf_range(-half, half)
				for s in STEMS:
					var p := at + Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
					var tall := rng.randf_range(0.9, 1.7)
					var lean := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU,
							rng.randf_range(-0.15, 0.15)))
					stems.append(Transform3D(lean.scaled(Vector3(1, tall, 1)), p + Vector3(0, tall * 0.5, 0)))
					# Every other stem carries a brown cattail head near its tip.
					if s % 2 == 0:
						heads.append(Transform3D(lean, p + lean * Vector3(0, tall * 0.85, 0)))
	_spawn(level, stems, 0.025, 1.0, Color(0.5, 0.52, 0.25), true)
	_spawn(level, heads, 0.06, 0.32, Color(0.36, 0.22, 0.12), false)
	_lay_stones(level, stones)
	# A cap of snow on every head, and a smaller one on the tip of every stem.
	for t in heads:
		reeds._full.append(Transform3D(t.basis, t.origin + t.basis * Vector3(0, 0.17, 0)))
	for t in stems:
		reeds._full.append(Transform3D(t.basis, t.origin + t.basis * Vector3(0, 0.5, 0)))
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.12
	ball.radial_segments = 6
	ball.rings = 3
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.94, 0.96, 1.0)
	white.roughness = 0.9
	ball.material = white
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = ball
	multi.instance_count = reeds._full.size()
	reeds.snow_caps = MultiMeshInstance3D.new()
	reeds.snow_caps.name = "PondReedSnow"
	reeds.snow_caps.multimesh = multi
	reeds.snow_caps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reeds.snow_caps.visible = false
	level.add_child(reeds.snow_caps)
	reeds.set_snow(0.0)
	return reeds


## Snow lies on the reeds: the caps swell with `amount` (0 to 1) and are gone while it is thin.
func set_snow(amount: float) -> void:
	if snow_caps == null:
		return
	snow_caps.visible = amount > 0.05
	if not snow_caps.visible:
		return
	var k := clampf(amount, 0.0, 1.0)
	var multi := snow_caps.multimesh
	for i in _full.size():
		var t := _full[i]
		multi.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3(k, k, k)), t.origin))


static func _spawn(level: Node3D, list: Array[Transform3D], radius: float, length: float, colour: Color, thin: bool) -> void:
	if list.is_empty():
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * (0.5 if thin else 1.0)
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 5
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mesh.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = list.size()
	for i in list.size():
		multi.set_instance_transform(i, list[i])
	var node := MultiMeshInstance3D.new()
	node.name = "PondReeds"
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(node)


## The stones at the water's edge: squashed, rounded lumps of grey stone, damp and dark below.
static func _lay_stones(level: Node3D, list: Array[Transform3D]) -> void:
	if list.is_empty():
		return
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 7
	ball.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.45, 0.41)
	mat.roughness = 0.85
	mat.vertex_color_use_as_albedo = true
	ball.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = ball
	multi.instance_count = list.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = list.size()
	for i in list.size():
		multi.set_instance_transform(i, list[i])
		var shade := rng.randf_range(0.75, 1.1)
		multi.set_instance_color(i, Color(shade, shade * rng.randf_range(0.96, 1.02), shade * rng.randf_range(0.9, 1.0)))
	var node := MultiMeshInstance3D.new()
	node.name = "PondStones"
	node.multimesh = multi
	level.add_child(node)

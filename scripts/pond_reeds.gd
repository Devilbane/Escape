class_name PondReeds
extends RefCounted
## Reeds and cattails along the bank of the village ponds, so the water looks like a real pond
## and not a cut-out. They stand on the open ground just outside the water (never on the pond
## tiles, which turn into ice walkable in winter) and keep their straw colour all year; snow
## settles on them like on everything else (see SnowCover).

## Clumps per metre of bank.
const CLUMPS_PER_METRE := 0.5
const STEMS := 5

## Grows the reeds round every pond tile in `ponds` (see Outdoor._pond_waters) in `level`.
static func grow(level: Outdoor, ponds: Array) -> void:
	var water := {}
	for w: Dictionary in ponds:
		water[w.cell] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.level_name + "schilf")
	var stems: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var half := Level.TILE * 0.5
	for w: Dictionary in ponds:
		var cell: Vector2i = w.cell
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + dir
			if water.has(next) or not level.is_open(next) or level.cell_char(next) != ".":
				continue
			var along := Vector3(dir.y, 0, dir.x)
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

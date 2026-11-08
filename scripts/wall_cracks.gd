class_name WallCracks
extends RefCounted
## The cracks in the stones of the village wall (see WallBrick). They grow with the damage the
## brick has taken, in three clearly different stages the player can read at a glance:
## light (a short hairline), medium (a longer crack with a branch) and heavy (a wide, forking
## crack across the stone). A stage adds to the one before, so a crack never moves or vanishes
## as the brick is hurt further; mending the brick closes them again.

## The brick has less than this share of its HP left at stage 1, 2 and 3.
const THRESHOLDS := [0.9, 0.6, 0.3]
const STAGES := 3
const VARIANTS := 3
## How far in front of the stone's face the crack lies, and its colour.
const LIFT := 0.006
const FACE := 0.39
const COLOUR := Color(0.07, 0.06, 0.055)
## Width of the crack's lines at each stage.
const WIDTHS := [0.022, 0.034, 0.05]

## The lines of each stage on a block face (x along the block, y up, in metres), one list of
## polylines per stage. The variants are mirrored and shifted so no two stones look alike.
const LINES := [
	[[[-0.1, 0.72], [-0.04, 0.6], [-0.12, 0.5], [-0.05, 0.4]]],
	[[[-0.05, 0.4], [-0.14, 0.3], [-0.08, 0.2], [-0.16, 0.08]], [[-0.12, 0.5], [-0.3, 0.44], [-0.42, 0.34]]],
	[[[-0.04, 0.6], [0.14, 0.52], [0.3, 0.56], [0.5, 0.46]], [[-0.08, 0.2], [0.12, 0.16], [0.3, 0.06]],
		[[-0.42, 0.34], [-0.6, 0.38], [-0.7, 0.26]], [[-0.1, 0.72], [-0.3, 0.7], [-0.46, 0.74]]],
]

static var _meshes := {}
static var _material: StandardMaterial3D


## The crack stage (0 for none, up to STAGES) of a brick with this share of its HP left.
static func stage(fraction: float) -> int:
	var n := 0
	for t: float in THRESHOLDS:
		if fraction < t:
			n += 1
	return n


## The mesh of one stage and variant: the lines drawn on both long faces of a block.
static func mesh(stage_no: int, variant: int) -> ArrayMesh:
	var key := stage_no * 10 + variant
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flip := -1.0 if variant % 2 == 1 else 1.0
	var shift := 0.12 * (variant - 1)
	for line: Array in LINES[stage_no - 1]:
		for i in line.size() - 1:
			var a := Vector2(line[i][0] * flip + shift, line[i][1])
			var b := Vector2(line[i + 1][0] * flip + shift, line[i + 1][1])
			for side in [-1.0, 1.0]:
				_segment(st, a, b, WIDTHS[stage_no - 1], side)
	_meshes[key] = st.commit()
	return _meshes[key]


static func _segment(st: SurfaceTool, a: Vector2, b: Vector2, width: float, side: float) -> void:
	var dir := (b - a).normalized()
	var off := Vector2(-dir.y, dir.x) * width * 0.5
	var z := side * (FACE + LIFT)
	var p := [a + off, a - off, b - off, b + off]
	var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
	st.set_normal(Vector3(0, 0, side))
	for k in order:
		st.add_vertex(Vector3(p[k].x, p[k].y, z))


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOUR
		_material.roughness = 1.0
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


## Adds the three stages of cracks to a stone; returns them, stage 1 first (all hidden).
static func add_to(stone: MeshInstance3D, variant: int) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for s in range(1, STAGES + 1):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(s, variant % VARIANTS)
		mi.material_override = material()
		mi.visible = false
		stone.add_child(mi)
		out.append(mi)
	return out


## Shows the stages up to `stage_no` and hides the rest.
static func show_stage(cracks: Array, stage_no: int) -> void:
	for i in cracks.size():
		cracks[i].visible = i < stage_no

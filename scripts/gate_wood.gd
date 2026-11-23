class_name GateWood
extends RefCounted
## The wooden leaves of the village gate (see WallBrick): aged boards with rounded, chipped
## edges, set side by side with small, uneven gaps and tops, two ledges across them, and iron
## straps with hinge eyes and round-headed nails, all with soft edges (see RoundedBox) instead of
## flat boxes. The boards share a few meshes and each carries its own grain (shaders/aged_wood.gdshader);
## the iron of a leaf is one merged mesh.

const SHADER := preload("res://shaders/aged_wood.gdshader")
const WOOD := Color(0.4, 0.28, 0.17)
const IRON := Color(0.17, 0.17, 0.19)
## How many boards a leaf has, and how many different board meshes there are.
const PLANKS := 5
const VARIANTS := 4
const GAP := 0.014
const DEPTH := 0.07
## Where the two ledges and iron straps run across the leaf (metres above its foot).
const STRAP_HEIGHTS := [0.55, 1.55]

static var _meshes := {}
static var _wood: ShaderMaterial
static var _iron: StandardMaterial3D


## The board mesh of a variant, standing on the origin, as high as the leaf.
static func plank_mesh(variant: int, width: float, height: float) -> ArrayMesh:
	var key := "plank%d_%d" % [absi(variant) % VARIANTS, roundi(width * 1000.0)]
	if not _meshes.has(key):
		var smooth := Graphics.preset != Graphics.PERFORMANCE
		_meshes[key] = RoundedBox.make(Vector3(width * 0.5, height * 0.5, DEPTH), 0.026, Vector3i(1, 2, 1),
				[0.002, 0.008, 0.02], 311 + variant * 17, Vector3(0, height * 0.5, 0), smooth)
	return _meshes[key]


## A ledge across the boards of a leaf.
static func ledge_mesh(length: float) -> ArrayMesh:
	var key := "ledge%d" % roundi(length * 1000.0)
	if not _meshes.has(key):
		_meshes[key] = RoundedBox.make(Vector3(length * 0.5, 0.085, 0.03), 0.02, Vector3i(3, 1, 1),
				[0.002, 0.007, 0.015], 977, Vector3.ZERO)
	return _meshes[key]


## The iron of one leaf, merged: a strap over each ledge on both faces with a hinge eye at the hinge
## end and a nail through every board. `dir` is the way the leaf runs from its hinge (+1 or -1 on x).
static func iron_mesh(dir: float, length: float, pitch: float) -> ArrayMesh:
	var key := "iron%d_%d" % [roundi(dir), roundi(length * 1000.0)]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strap := RoundedBox.make(Vector3((length - 0.06) * 0.5, 0.05, 0.013), 0.011, Vector3i(3, 1, 1), [0.0, 0.002, 0.004], 59, Vector3.ZERO)
	var eye := RoundedBox.make(Vector3(0.075, 0.07, 0.025), 0.02, Vector3i(1, 1, 1), [0.0, 0.002, 0.004], 61, Vector3.ZERO)
	var nail := RoundedBox.make(Vector3(0.024, 0.024, 0.016), 0.014, Vector3i(1, 1, 1), [0.0, 0.0, 0.002], 67, Vector3.ZERO)
	var face_z := DEPTH + 0.056 + 0.013
	for y: float in STRAP_HEIGHTS:
		for side in [-1.0, 1.0]:
			st.append_from(strap, 0, Transform3D(Basis(), Vector3(dir * (0.03 + (length - 0.06) * 0.5), y, side * face_z)))
			st.append_from(eye, 0, Transform3D(Basis(), Vector3(dir * 0.06, y, side * (face_z + 0.004))))
			for k in PLANKS:
				var x := dir * (pitch * (k + 0.5) + 0.04 * (k % 2) - 0.02)
				if k == 0:
					continue
				st.append_from(nail, 0, Transform3D(Basis(), Vector3(x, y, side * (face_z + 0.012))))
	_meshes[key] = st.commit()
	return _meshes[key]


static func wood_material() -> ShaderMaterial:
	if _wood == null:
		_wood = ShaderMaterial.new()
		_wood.shader = SHADER
		_wood.set_shader_parameter("albedo_color", WOOD)
	return _wood


static func iron_material() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.albedo_color = IRON
		_iron.roughness = 0.62
		_iron.metallic = 0.45
	return _iron


## Builds one leaf of the gate under `leaf` (its origin is the hinge, the leaf runs towards `dir`
## on x). `seed` makes the boards of one gate unlike the boards of the next.
static func build_leaf(leaf: Node3D, dir: float, length: float, height: float, foot: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pitch := length / PLANKS
	var width := pitch - GAP
	for k in PLANKS:
		# Boards of slightly different height and a hair out of true, as if put up by hand.
		var shorter := rng.randf_range(0.0, 0.07)
		var lift := rng.randf_range(0.0, 0.04)
		var mi := MeshInstance3D.new()
		mi.mesh = plank_mesh(k + seed, width, height)
		mi.material_override = wood_material()
		mi.set_instance_shader_parameter("plank", rng.randf() * 10.0)
		mi.scale.y = (height - shorter - lift) / height
		mi.position = Vector3(dir * pitch * (k + 0.5), foot + lift, rng.randf_range(-0.008, 0.008))
		mi.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.012, 0.012))
		leaf.add_child(mi)
	for y: float in STRAP_HEIGHTS:
		for side in [-1.0, 1.0]:
			var ledge := MeshInstance3D.new()
			ledge.mesh = ledge_mesh(length - 0.08)
			ledge.material_override = wood_material()
			ledge.set_instance_shader_parameter("plank", rng.randf() * 10.0)
			ledge.position = Vector3(dir * (length * 0.5 + 0.02), y, side * (DEPTH + 0.03 - 0.004))
			ledge.rotation.z = rng.randf_range(-0.01, 0.01)
			leaf.add_child(ledge)
	var iron := MeshInstance3D.new()
	iron.mesh = iron_mesh(dir, length, pitch)
	iron.material_override = iron_material()
	leaf.add_child(iron)

class_name Crate
extends StaticBody3D
## A small wooden crate the hero can carry in the bag ("kiste" in Items),
## set down on the floor again, stack and climb. It is a solid cube of SIZE
## metres: walking into one lifts the hero on top (see Player), and a hero
## who jumps against a crate pulls themselves up when its top is within
## reach of their hands.

## Edge length in metres. A hero is 2.4 m tall: one crate is a step up,
## two stacked crates need a jump (or a third crate as a step).
const SIZE := 0.8
## How many crates fit on top of each other.
const MAX_STACK := 3
const MODEL := "res://assets/village/crate_A_big.gltf"

static var _model_box := AABB()
## What the crate looks like (its collision box stays as it is while this
## grows or shrinks when the crate is set down or picked up).
var model: Node3D


func _ready() -> void:
	add_to_group("crate")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * SIZE
	shape.shape = box
	shape.position.y = SIZE * 0.5
	add_child(shape)
	model = _make_model()
	add_child(model)


## The crate model, squeezed into a SIZE cube standing on the ground.
static func _make_model() -> Node3D:
	var scene: Node3D = load(MODEL).instantiate()
	# Old, weathered wood like the other props (see WeatheredProps).
	WeatheredProps.weather_model(scene, "crate_A_big")
	if _model_box.size == Vector3.ZERO:
		var first := true
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh_box: AABB = _transform_to(scene, mi) * (mi as MeshInstance3D).mesh.get_aabb()
			_model_box = mesh_box if first else _model_box.merge(mesh_box)
			first = false
	var holder := Node3D.new()
	var s := Vector3.ONE
	if _model_box.size.x > 0.0 and _model_box.size.y > 0.0 and _model_box.size.z > 0.0:
		s = Vector3(SIZE / _model_box.size.x, SIZE / _model_box.size.y, SIZE / _model_box.size.z)
	scene.scale = s
	var middle := _model_box.get_center()
	scene.position = Vector3(-middle.x * s.x, -_model_box.position.y * s.y, -middle.z * s.z)
	holder.add_child(scene)
	return holder


## The transform of `node` relative to `root` (both outside the tree).
static func _transform_to(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## The height of the crate's top surface.
func top() -> float:
	return global_position.y + SIZE


## Whether a point lies above (or below) this crate's footprint, give or
## take `margin` metres.
func covers(point: Vector3, margin := 0.0) -> bool:
	var half := SIZE * 0.5 + margin
	return absf(point.x - global_position.x) <= half and absf(point.z - global_position.z) <= half

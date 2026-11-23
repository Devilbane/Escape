class_name AppleHoard
extends Node3D
## A hedgehog's apple hoard (see Hedgehog): a little heap of apples on the ground under its
## tree. It starts with a few and grows by one every time the hedgehog carries another home
## on its spines.

## The most apples the heap holds, and how many it starts with.
const MAX := 8
const START := 3
## An apple's radius (metres).
const RADIUS := 0.1
## Where each apple lies: a ring of four on the ground, then the rest piled on top.
const SPOTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0), Vector3(0.19, 0.0, 0.07), Vector3(-0.17, 0.0, 0.1), Vector3(0.03, 0.0, -0.19),
	Vector3(-0.12, 0.0, -0.12), Vector3(0.1, 0.14, 0.02), Vector3(-0.07, 0.15, 0.04), Vector3(0.02, 0.27, -0.03),
]
const COLOURS: Array[Color] = [Color(0.78, 0.12, 0.09), Color(0.56, 0.7, 0.16), Color(0.82, 0.55, 0.14)]

static var _mesh: SphereMesh
static var _mats: Array[StandardMaterial3D] = []

## How many apples lie in the heap.
var count := 0


func _ready() -> void:
	for i in START:
		add_apple()


## One more apple on the heap (none once it is full). Returns whether there was room.
func add_apple() -> bool:
	if count >= MAX:
		return false
	var apple := MeshInstance3D.new()
	apple.mesh = _apple_mesh()
	apple.material_override = _material(count)
	apple.position = SPOTS[count] + Vector3(0, RADIUS * 0.9, 0)
	apple.rotation.y = count * 1.7
	apple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(apple)
	count += 1
	return true


## Where the next apple will lie (world), for the hedgehog to set its apple down.
func next_spot() -> Vector3:
	return global_position + SPOTS[mini(count, MAX - 1)] + Vector3(0, RADIUS * 0.9, 0)


static func _apple_mesh() -> SphereMesh:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = RADIUS
		_mesh.height = RADIUS * 1.9
		_mesh.radial_segments = 10
		_mesh.rings = 5
	return _mesh


## The look of apple `i`: red, green or golden in turn.
static func _material(i: int) -> StandardMaterial3D:
	if _mats.is_empty():
		for c in COLOURS:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.roughness = 0.55
			_mats.append(m)
	return _mats[i % _mats.size()]


## A fresh apple mesh for something that carries or drops one (a Hedgehog), of the heap's apples.
static func make_apple(i: int) -> MeshInstance3D:
	var apple := MeshInstance3D.new()
	apple.mesh = _apple_mesh()
	apple.material_override = _material(i)
	apple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return apple

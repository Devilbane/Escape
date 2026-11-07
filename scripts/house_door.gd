class_name HouseDoor
extends Node3D
## The door of a village house (see VillageHouse): a plank leaf on a hinge that
## swings out into the street when someone goes in or out, and closes again on
## its own a moment later. Nothing waits on it for long: the swing takes
## OPEN_TIME, and whoever opens it may walk in at once after that.
##
## The node sits on the hinge side of the doorway; its "Leaf" child is the plank
## and turns about the hinge. Behind the leaf a dark recess fills the doorway,
## so an open door shows a dark room and not the plaster of the wall.

## How far the leaf swings open (radians, negative: out towards +z, the street).
const OPEN_ANGLE := -1.75
## Seconds to open and to close, and how long it stays open by default.
const OPEN_TIME := 0.25
const CLOSE_TIME := 0.35
const HOLD := 1.6
## Doorway size (metres), as the plank door of VillageHouse.
const WIDTH := 1.1
const HEIGHT := 2.1

var leaf: Node3D
var _tween: Tween


## The doorway recess and the leaf (meshes made by the house).
func setup(recess_mesh: MeshInstance3D, leaf_mesh: MeshInstance3D) -> HouseDoor:
	name = "HouseDoor"
	recess_mesh.name = "Recess"
	add_child(recess_mesh)
	leaf = Node3D.new()
	leaf.name = "Leaf"
	leaf.add_child(leaf_mesh)
	add_child(leaf)
	return self


## 0 when shut, 1 when open as far as it goes.
func openness() -> float:
	return clampf(leaf.rotation.y / OPEN_ANGLE, 0.0, 1.0) if leaf else 0.0


func is_open() -> bool:
	return openness() > 0.5


## Swings open, stays `hold` seconds and swings shut again. Called while it is
## open already, it only starts the wait over.
func swing(hold := HOLD) -> void:
	if leaf == null:
		return
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		return
	_tween = create_tween()
	var left := 1.0 - openness()
	if left > 0.0:
		_tween.tween_property(leaf, "rotation:y", OPEN_ANGLE, OPEN_TIME * left).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(leaf, "rotation:y", 0.0, CLOSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## A level taken away while the door swings leaves it shut.
func _exit_tree() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if leaf:
		leaf.rotation.y = 0.0

class_name AshLedge
extends Crate
## A ledge ("a" on a dungeon map): a block of old masonry that fills a whole
## tile and stands HEIGHT metres high, three crates tall. A hero's jump alone
## does not reach its top (the hands catch at most GRAB_REACH above the
## highest point of the jump), so the way over it needs a step: a crate from
## the bag set down at its foot (Q), or one of the heavy stone blocks of the
## floor pushed up against it. Standing on the step, a jump against the ledge
## pulls the hero up (see Player._try_climb), and the top can be walked over
## and left again on the other side by simply stepping off.
##
## It is a kind of Crate to the hero, so the climbing code treats it like one,
## but it is never in Level.crates: it cannot be picked up, stacked on or
## carried off. Skeletons and bandits cannot pass it (the tile is solid for
## their path finding, see Level.SOLID).

## The height of the ledge's top above the floor: one crate, a jump and the
## hands' reach (0.8 + 1.56 + 0.7) just clear it, a jump alone (1.56 + 0.7)
## does not.
const HEIGHT := 2.4
## Edge of the block (metres): a tile, less a joint.
const EDGE := Level.TILE - 0.1
const SHADE := Color(0.4, 0.38, 0.35)
const CAP := Color(0.5, 0.47, 0.42)


func _ready() -> void:
	add_to_group("ledge")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(EDGE, HEIGHT, EDGE)
	shape.shape = box
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	model = Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(EDGE, HEIGHT - 0.1, EDGE)
	body.mesh = mesh
	body.material_override = StoneBlock.stone_material(SHADE)
	body.position.y = (HEIGHT - 0.1) * 0.5
	model.add_child(body)
	# A flat capstone on top, so the edge to grab reads at a glance.
	var cap := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(EDGE + 0.1, 0.18, EDGE + 0.1)
	cap.mesh = slab
	cap.material_override = StoneBlock.stone_material(CAP)
	cap.position.y = HEIGHT - 0.09
	model.add_child(cap)
	add_child(model)


func top() -> float:
	return global_position.y + HEIGHT


func covers(point: Vector3, margin := 0.0) -> bool:
	var half := EDGE * 0.5 + margin
	return absf(point.x - global_position.x) <= half and absf(point.z - global_position.z) <= half

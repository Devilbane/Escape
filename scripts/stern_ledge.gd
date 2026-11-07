class_name SternLedge
extends Crate
## A heap of rubble in Sternhall (the map's "{", see SternHall) as high as
## a man: too high to climb from the floor, but a hero standing on a crate
## jumps and pulls themselves up onto it, as onto a stack of crates (see
## Player._try_climb). It fills its gap from wall to wall, so the only way
## past is over the top. It is a crate only to the hero's hands: it is never
## picked up or stacked away (it is not in Level.crates).

## Its height, and how deep it is along the gap (it is a tile wide across).
const HEIGHT := 2.4
const DEPTH := 1.6

## Its size: TILE across the gap, DEPTH along it, HEIGHT high.
var extent := Vector3(Level.TILE, HEIGHT, DEPTH)


func _init(across_x := true) -> void:
	extent = Vector3(Level.TILE, HEIGHT, DEPTH) if across_x else Vector3(DEPTH, HEIGHT, Level.TILE)


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent
	shape.shape = box
	shape.position.y = HEIGHT * 0.5
	add_child(shape)


func top() -> float:
	return global_position.y + HEIGHT


func covers(point: Vector3, margin := 0.0) -> bool:
	return absf(point.x - global_position.x) <= extent.x * 0.5 + margin \
			and absf(point.z - global_position.z) <= extent.z * 0.5 + margin

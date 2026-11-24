class_name SmithCottage
extends RefCounted
## Gorm's own little house beside the smithy (map letter ß): a small VillageHouse of the same stone,
## timber and ivy as the villagers' houses, one can walk into (see WalkIn). The smithy itself, its
## furnace and Gorm's forge and anvil stay out in the open air where he works by day; at nightfall
## he walks over to his house and sleeps in its one bed (see VillageBeds), and nobody else does
## (the house is his alone, see WalkIn.house_near and Outdoor.own_homes).
##
## Inside: his bed along the back wall, a table with a stool and a tankard, his chest and a barrel
## in the corner, and a rack with a few blades he keeps for himself.

## Whose house it is: the smith (see Villager.ROLES).
const OWNER := "1"
## The house is narrower than the villagers' homes, its door in the middle of the front.
const STYLE := {"max_w": 5.2, "max_d": 4.0, "door_x": 0.0}


## The house for a footprint of `room` metres. It rolls its own dice, so the other houses of the
## village look as they always did.
static func build(room: Vector2, block: Rect2i, glass: Material) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("smith cottage %s" % block.position)
	var node := VillageHouse.build(room, rng, glass, STYLE)
	node.name = "SmithCottage"
	return node


## The furniture (see WalkIn.open_house): the bed lies along the back wall with its head to the
## left wall, so the way from the door to it stays free.
static func furnish(walk_in: WalkIn, rec: Dictionary) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	# Turned a quarter: the bed's own foot (+z) points to the right wall, its left side to the front.
	var turn := PI * 0.5
	var origin := Vector3(room.position.x + 0.02 - CosyBed.HEAD, floor_y, back + 0.02 + CosyBed.RIGHT)
	var bed := CosyBed.build(house, origin, turn, false)
	bed.name = "SmithBed"
	var bed_mid := origin.x + (CosyBed.HEAD + CosyBed.FOOT) * 0.5
	var bed_front := origin.z - CosyBed.LEFT
	walk_in._solid(rec, Vector3(bed_mid, floor_y + 0.5, (back + bed_front) * 0.5), Vector3(CosyBed.FOOT - CosyBed.HEAD, 1.0, bed_front - back))
	var stand := house.transform * Vector3(bed_mid, floor_y, bed_front + 0.55)
	rec.beds.append({"pos": house.transform * origin, "rot": house.rotation.y + turn, "by": null, "stand": stand})
	# His bed is on the ground floor, not up a ladder (see VillageBeds._on_ground). Should it ever be
	# taken (nobody but Gorm sleeps here), whoever comes waits beside it.
	rec["ground_beds"] = true
	rec["ladder"] = stand
	rec["ladder_top"] = stand
	# His chest in the corner beyond the foot of the bed, a barrel in front of it.
	var right := room.end.x
	var chest := WalkInFurniture.crate(0.6)
	chest.name = "SmithChest"
	chest.position = Vector3(right - 0.4, floor_y, back + 0.4)
	house.add_child(chest)
	walk_in._solid(rec, Vector3(right - 0.4, floor_y + 0.3, back + 0.4), Vector3(0.6, 0.6, 0.6))
	var barrel := WalkInFurniture.barrel()
	barrel.position = Vector3(right - 0.4, floor_y, back + 1.12)
	house.add_child(barrel)
	walk_in._solid(rec, Vector3(right - 0.4, floor_y + 0.45, back + 1.12), Vector3(0.64, 0.9, 0.64))
	# A stool in the front corner on the right, beside the way in, to sit on and look at the room.
	var stool_at := Vector3(right - 0.65, floor_y, room.end.y - 0.75)
	var stool := WalkInFurniture.stool()
	stool.position = stool_at
	house.add_child(stool)
	Seats.add_stool(walk_in, rec, stool_at, Vector3(0, floor_y, room.get_center().y))
	# A rack with a few blades of his own on the left wall, by the door.
	var rack := WalkInFurniture.weapon_rack(1.0)
	rack.name = "SmithRack"
	rack.position = Vector3(room.position.x + 0.2, floor_y, room.end.y - 0.7)
	rack.rotation.y = PI * 0.5
	house.add_child(rack)
	walk_in._solid(rec, Vector3(room.position.x + 0.2, floor_y + 0.75, room.end.y - 0.7), Vector3(0.35, 1.5, 1.0))

class_name WaterRound
extends RefCounted
## Hanna the water carrier's round: she fills her two buckets at the fountain and carries them on her
## yoke (see WaterYoke) to the doors of the shops and the tavern round the village centre, one after
## the other in no fixed order, and back again. Where the fountain stands and which doors she calls at
## come from the village map (Outdoor.spots.fountain, Outdoor.doors).

const ROLE := "9"
## The doors she calls at (the building letters of Outdoor.doors): the tavern, the shop, the forge, the
## post office and the bank.
const CALLS := ["n", "m", "j", "o", "b"]
## How close to the fountain's spot (metres) counts as being at it.
const AT_FOUNTAIN := 2.5


## Whether `role` is the water carrier.
static func is_carrier(role: String) -> bool:
	return role == ROLE


## Where she fills the buckets, or Vector3.INF when the map has no fountain or well.
static func fill_spot(level: Outdoor) -> Vector3:
	var at: Array = level.spots.fountain if not level.spots.fountain.is_empty() else level.spots.well
	return at[0] if not at.is_empty() else Vector3.INF


## The doors she calls at that this map has, nearest the fountain first.
static func stops(level: Outdoor) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for letter: String in CALLS:
		if level.doors.has(letter):
			out.append(level.doors[letter])
	var fill := fill_spot(level)
	if fill != Vector3.INF:
		out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(fill) < b.distance_to(fill))
	return out


## Whether the yoke is on her shoulders: by day, out in the village, upright.
static func carries(v: Villager) -> bool:
	return v.visible and not v.night and not v.at_home and not v.is_frozen() and not v.is_posed()

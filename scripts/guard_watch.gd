class_name GuardWatch
extends RefCounted
## The town guard's watch on the west gate (see Villager, plan "patrol").
##
## Slimes crawl out of the pond in the woods, and the pond lies beyond the west
## gate, so that is where they come from. Most of the time the guard makes his
## rounds through the village and only now and then looks in at the west gate.
## At night, in rain and storm, and while the puddles still lie after the rain,
## he goes there far more often. At the gate he looks out for a slime: when he
## sees one he calls the alarm once, the gate shuts and the brave take their
## posts (see VillageWall), and he draws his blade and holds the gate himself.

## The chance that a leg of his round leads to the west gate: in ordinary
## times, and when the gate wants watching (night, rain, storm, wet ground).
const CHANCE_CALM := 0.12
const CHANCE_WATCHFUL := 0.7
## How much water must lie in the puddles to count as "just after rain".
const WET_GROUND := 0.05
## How long he stands at the gate (seconds), at least and at most.
const STAND_MIN := 7.0
const STAND_MAX := 12.0
## How far from the gate he sees a slime, and how long he is quiet after a call.
const SIGHT := 26.0
const CALL_PAUSE := 20.0
const CALL := "Ein Schleim am Westtor! Tor zu, zu den Waffen!"
const NEWS := "Wache Ulrich hat am Westtor einen Schleim entdeckt!"
const COLOR := Color(1.0, 0.75, 0.3)


## The gate on the west side of the village, null when there is no wall.
static func west_gate(o: Outdoor) -> WallBrick:
	var best: WallBrick = null
	for g in o.village_wall.gates:
		if best == null or g.global_position.x < best.global_position.x:
			best = g
	return best


## Whether the weather or the ground says the gate wants watching: night,
## rain, storm, or puddles that have not dried yet.
static func watchful(o: Outdoor) -> bool:
	if o.night or o.weather in [Weather.RAIN, Weather.STORM]:
		return true
	return o.puddles != null and o.puddles.water > WET_GROUND


static func chance(o: Outdoor) -> float:
	return CHANCE_WATCHFUL if watchful(o) else CHANCE_CALM


## Whether the next leg of the round leads to the west gate.
static func goes_to_gate(o: Outdoor, roll: float) -> bool:
	return west_gate(o) != null and roll < chance(o)


## Where he stands: inside the wall, by the west gate.
static func post(o: Outdoor) -> Vector3:
	var gate := west_gate(o)
	return o.village_wall.stand_of(o, gate) if gate != null else Vector3.INF


## The slime he can see from the west gate, or null.
static func slime_in_sight(o: Outdoor) -> Enemy:
	var gate := west_gate(o)
	if gate == null:
		return null
	return VillageWall.nearest_slime(o, gate.global_position, SIGHT)

class_name BlessRound
extends RefCounted
## Priestess Elsbeth's blessing round. Once a day, after the morning in the temple, she walks out
## with her staff to bless the village's holy and useful places one after the other: the temple,
## the entrances (the gates in the wall), the fountain and the smithy. At each she stops, raises
## the staff, says what she is blessing in a speech bubble and the place is lit by a short shower of
## golden light (see BlessFx). Where frozen Fritz stands (see FrozenFritz) she comes across him and
## thaws him with a warm spell instead, for the rest of that day.
##
## This class finds the places and keeps the round; the walking and the casting are Villager's
## "bless" task (see Villager._bless_step).

const ROLE := "O"
## The hours of the day (see DayNight; an hour is 50 seconds) the round may begin in: after the
## temple's morning gathering (see TempleMorning.END) and well before the noon meal.
const FROM := 8.2
const UNTIL := 9.6
## Frozen Fritz is thawed whenever she is free between these hours.
const THAW_FROM := 8.2
const THAW_UNTIL := 17.0
## How close (metres) she must stand to a place before she casts, and how long a cast takes.
const ARRIVE := 1.4
const CAST_TIME := 3.2
## The second of the cast the words and the light come at (the staff is high by then).
const CAST_AT := 0.55
## How far from a place she may stand (tiles) and how often she tries to reach it before giving it up.
const REACH_TILES := 7
const TRIES := 3
## Two entrances closer than this (metres) count as one.
const GATE_MERGE := 6.0

const KIND_TEMPLE := "temple"
const KIND_GATE := "gate"
const KIND_FOUNTAIN := "fountain"
const KIND_SMITHY := "smithy"
const KIND_THAW := "thaw"
## What she says at each (German; see scripts/lang/bless_round.gd).
const SAYS := {
	"temple": "Ihr Götter, segnet dieses Haus und alle, die eintreten.",
	"gate": "Kein Unheil trete durch dieses Tor.",
	"fountain": "Möge dieses Wasser klar und süß bleiben.",
	"smithy": "Möge die Esse wahr brennen.",
	"thaw": "Eis, weiche! Wärme kehre zu Fritz zurück.",
}
## What Fritz mumbles once he is warm again.
const THANKS := "Brrr... danke, Priesterin!"
## How wide the light on the ground is at each place (metres, radius).
const RADIUS := {"temple": 2.6, "gate": 2.0, "fountain": 2.1, "smithy": 2.6, "thaw": 1.6}


## One place: its kind, where she stands, and the point of the ground the blessing falls on.
class Site:
	var kind := ""
	var stand := Vector3.ZERO
	var at := Vector3.ZERO

	func _init(k: String, s: Vector3, a: Vector3) -> void:
		kind = k
		stand = s
		at = a


## A round under way: the places still to go and where she is in the current one.
class Round:
	var sites: Array = []
	var index := 0
	## "go" (walking there), "cast" (staff raised) or "done".
	var step := "go"
	var clock := 0.0
	var tries := 0
	var cast_done := false

	func site() -> Site:
		return sites[index] if index < sites.size() else null

	## On to the next place; true while there is one.
	func next() -> bool:
		index += 1
		step = "go"
		clock = 0.0
		tries = 0
		cast_done = false
		return index < sites.size()


## The places to bless now, or [] when nothing is due: the whole round once a day in the morning
## (`blessed_day` is the day of the last one), or only Fritz when he is frozen and it is day.
static func due(level: Outdoor, blessed_day: int) -> Array:
	if level == null or level.night or level.village_alarm.raised or level.hour < 0.0:
		return []
	var out: Array = []
	if blessed_day != level.day and level.hour >= FROM and level.hour < UNTIL:
		out = sites(level)
	elif level.hour >= THAW_FROM and level.hour < THAW_UNTIL:
		var thaw := thaw_site(level)
		if thaw != null:
			out = [thaw]
	return out


## All the places of the daily round in the order she visits them: temple, entrances (each the nearest
## one to the one before), fountain, smithy, and Fritz where he stands frozen.
static func sites(level: Outdoor) -> Array:
	var out: Array = []
	var temple := temple_site(level)
	if temple != null:
		out.append(temple)
	var from: Vector3 = temple.stand if temple != null else level.player.global_position
	for g: Site in gate_sites(level, from):
		out.append(g)
	var fountain := _block_site(level, "F", KIND_FOUNTAIN)
	if fountain != null:
		out.append(fountain)
	var thaw := thaw_site(level)
	if thaw != null:
		out.append(thaw)
	var smithy := _block_site(level, "j", KIND_SMITHY)
	if smithy != null:
		out.append(smithy)
	return out


## The door of the temple: she blesses it from the street before the porch.
static func temple_site(level: Outdoor) -> Site:
	var rec := TempleMorning.temple_of(level)
	if rec.is_empty():
		return null
	var node: Node3D = rec.node
	var door: Vector3 = rec.door
	var porch := node.global_transform * Vector3(door.x, 0.0, WalkIn.PORCH_END + 1.5 / node.scale.x)
	var stand := _stand_near(level, porch, porch)
	if stand == Vector3.INF:
		return null
	return Site.new(KIND_TEMPLE, stand, Vector3(porch.x, stand.y, porch.z))


## The gates of the village wall, the nearest first from `from`, two next to each other as one.
static func gate_sites(level: Outdoor, from: Vector3) -> Array:
	var left: Array = []
	for g: WallBrick in level.village_wall.gates:
		if is_instance_valid(g):
			left.append(g)
	var out: Array = []
	var here := from
	while not left.is_empty():
		left.sort_custom(func(a: WallBrick, b: WallBrick) -> bool: return _flat(a.global_position, here) < _flat(b.global_position, here))
		var g: WallBrick = left.pop_front()
		var mid := g.global_position
		var twin := false
		for s: Site in out:
			if _flat(s.at, mid) < GATE_MERGE:
				twin = true
		if twin:
			continue
		var stand := level.village_wall.stand_of(level, g)
		out.append(Site.new(KIND_GATE, stand, Vector3(mid.x, stand.y, mid.z)))
		here = mid
	return out


## Fritz where he stands frozen (null when he does not): she walks up to him and thaws him.
static func thaw_site(level: Outdoor) -> Site:
	if level.fritz_thawed_day == level.day:
		return null
	var fritz := frozen_fritz(level)
	if fritz == null:
		return null
	var stand := _stand_near(level, fritz.global_position, fritz.global_position)
	if stand == Vector3.INF:
		return null
	var p := fritz.global_position
	return Site.new(KIND_THAW, stand, Vector3(p.x, stand.y, p.z))


## Fritz, while he stands frozen on the square.
static func frozen_fritz(level: Outdoor) -> Villager:
	for v: Villager in level.villagers:
		if v.role == FrozenFritz.ROLE and v.is_frozen():
			return v
	return null


## A building or the fountain made of the map letter `letter`: she stands on the open tile nearest to it.
static func _block_site(level: Outdoor, letter: String, kind: String) -> Site:
	var sum := Vector3.ZERO
	var n := 0
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if level.cell_char(c) == letter:
				sum += level.cell_to_world(c)
				n += 1
	if n == 0:
		return null
	var middle := sum / n
	var stand := _stand_near(level, middle, middle)
	if stand == Vector3.INF:
		return null
	# The light falls between her and the place, a little way in front of the middle of a building.
	var at := middle
	if kind != KIND_FOUNTAIN:
		var to := middle - stand
		to.y = 0.0
		at = middle - to.normalized() * minf(to.length() * 0.5, 3.0)
	# The fountain's light lies on the water of its basin.
	var level_y := stand.y + (VillageFountain.WATER if kind == KIND_FOUNTAIN else 0.0)
	return Site.new(kind, stand, Vector3(at.x, level_y, at.z))


## The open street tile (its middle) nearest to `near`, within REACH_TILES, that is a walk away from
## the middle of the square rather than behind a building. INF when there is none.
static func _stand_near(level: Outdoor, near: Vector3, _aim: Vector3) -> Vector3:
	var centre := level.world_to_cell(near)
	var square := Vector3.ZERO
	if not level.spots.square.is_empty():
		square = level.spots.square[0]
	var best := Vector3.INF
	var best_score := INF
	for dy in range(-REACH_TILES, REACH_TILES + 1):
		for dx in range(-REACH_TILES, REACH_TILES + 1):
			var c := centre + Vector2i(dx, dy)
			if not level.is_open(c):
				continue
			var p := level.cell_to_world(c)
			var score := _flat(p, near) + 0.35 * _flat(p, square)
			# Not right on top of what is blessed: she stands a pace or two away.
			if _flat(p, near) < 1.6:
				score += 6.0
			if score < best_score:
				best_score = score
				best = p
	return best


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

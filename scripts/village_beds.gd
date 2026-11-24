class_name VillageBeds
extends RefCounted
## The villagers go to bed in the houses one can walk into (see WalkIn). At nightfall a villager who
## sleeps walks home as before; at the door they now step in, walk to the ladder by the side wall
## and climb it, hand over hand and foot over foot the way the hero climbs (see LadderPose), up
## through the hatch to the room on the floor above (see WalkIn._furnish_upstairs). There they walk
## to their bed, hop in and sleep (Gorm's cottage has his bed on the ground floor, see SmithCottage:
## he walks to it and lies down in sight). Two beds to a house at most (WalkIn.MAX_BEDS): a villager whose
## nearest house has no free bed goes in the old way and is gone until the morning. In the morning
## they get up, walk to the hatch, climb down, hop off the last rungs, walk out of the door and go
## back to their day.
##
## Upstairs a villager is seen only while the hero is up there too (the floor above is hidden while
## the hero is on the ground floor, and walled in from outside); on the ladder, from the hero's
## floor below, they are gone once their head is through the hatch.
##
## Called by Villager: `enter` from Villager._hide_inside when they reach the door at nightfall,
## `step` every physics tick of their "home" task, `rise` when the morning comes (see
## Villager._come_out) and `leave_at_once` when anything else calls them out in a hurry (the
## mason to a broken wall, a fright). A villager's trip is kept on them (Villager.bed_trip).
## With WalkIn.houses off there are no houses to walk into, `enter` says no and the villagers
## vanish at the door as they always did.

## The steps of a trip that happen up on the floor above.
const UPSTAIRS := ["to_bed", "to_side", "tuck", "upstairs", "rise", "to_stand", "to_hatch"]
## Seconds: the few steps to the side of the bed, going to bed and getting up (see BedRise).
const SIDE_TIME := 0.4
const TUCK_TIME := BedRise.TUCK_LENGTH
const RISE_TIME := BedRise.RISE_LENGTH
## On the ladder a villager is out of sight from below while their feet are higher than this below
## the hatch (metres): the head is through it.
const HIDDEN_BELOW := 1.2
## How near a path point counts as reached (metres), and how near the door it gets pushed open.
const ARRIVE := 0.15
const DOOR_PUSH := 2.6
## How long the door stays open after the last step within DOOR_PUSH of it (seconds).
const DOOR_HOLD := 0.9
## The longest a walk inside may take before the villager is simply put where they were going
## (something in the way), seconds.
const GIVE_UP := 20.0


## Starts a villager's way to bed in the house nearest to them. With `at_once` they are in bed at
## once: a game loaded at night, a villager sent home on the spot. False when there is no house to
## walk into nearby, or no free bed in it: they go in the old way.
static func enter(v: Villager, at_once: bool) -> bool:
	var walk_in: WalkIn = v.level.get("walk_in") if v.level != null else null
	if walk_in == null:
		return false
	var house := walk_in.owned_house(v.role)
	if house.is_empty():
		house = walk_in.home_for(v.role, v.level.cell_to_world(v.home))
	if house.is_empty():
		house = walk_in.house_near(v.global_position, 9.0, v.role)
	if house.is_empty():
		return false
	var bed := _free_bed(house)
	if bed.is_empty():
		return false
	var way := walk_in.door_points(house)
	bed.by = v
	# Down the stairs first to a bed in a cellar (the guild master's, see GuildHall).
	var path: Array = [_approach(way), way[0], way[1]]
	path.append_array(house.get("inner_way", []))
	path.append(house.ladder)
	v.bed_trip = {"house": house, "bed": bed, "step": "in", "way": path, "t": 0.0, "clock": 0.0}
	v.bed_trip.clock = _slack(v.global_position, path)
	if at_once:
		if _on_ground(house, bed):
			_lie_on_ground(v)
		else:
			_settle(v)
	return true


## Whether the bed stands on the ground floor of its house (the smith's cottage), where the sleeper
## lies in sight of whoever comes in, instead of up the ladder.
static func _on_ground(house: Dictionary, bed: Dictionary) -> bool:
	return bool(house.get("ground_beds", false)) and not bed.is_empty()


## Into a bed on the ground floor: lies in it under the blanket, in sight, with the name hidden like upstairs.
static func _lie_on_ground(v: Villager) -> void:
	var trip := v.bed_trip
	_lie_down(v, trip, true)
	v.visible = not v.has_meta(InsideView.HIDDEN)
	trip.step = "asleep"
	v.reset_physics_interpolation()


static func _free_bed(house: Dictionary) -> Dictionary:
	for bed: Dictionary in house.beds:
		var by = bed.get("by")
		if by == null or not is_instance_valid(by) or not is_same((by as Villager).bed_trip.get("bed"), bed):
			return bed
	return {}


## Whether the hero is up on the floor above of the house of `trip`.
static func _hero_up(v: Villager, trip: Dictionary) -> bool:
	var walk_in: WalkIn = v.level.get("walk_in") if v.level != null else null
	return walk_in != null and walk_in.hero_upstairs_in(trip.house)


## Whether the hero is inside the house on its storey `storey` (see GuildHall.storey_of).
static func _hero_on(house: Dictionary, storey: int) -> bool:
	return bool(house.get("inside", false)) and int(house.get("storey", -9)) == storey


## Whether the villager is out of sight at home: in the house the old way, upstairs while the hero
## is not, or on the ladder with the head through the hatch.
static func unseen(v: Villager) -> bool:
	var trip := v.bed_trip
	if trip.is_empty():
		return true
	var storey = trip.get("house", {}).get("bed_storey")
	if storey != null and (String(trip.step) in UPSTAIRS or trip.step == "asleep"):
		# A bed up in a tower (see MageTower): seen only while the hero is on that storey of it.
		return not _hero_on(trip.house, int(storey))
	if String(trip.step) in UPSTAIRS:
		# A bed on the ground floor is in sight (see _on_ground).
		if not trip.get("bed", {}).is_empty() and _on_ground(trip.house, trip.bed):
			return false
		return not _hero_up(v, trip)
	return bool(trip.get("hidden", false))


## Shows or hides the villager as `unseen` says, where the walls let the hero see (see InsideView).
static func _mind_sight(v: Villager) -> void:
	if v.bed_trip.is_empty():
		return # Out of the door: the villager's own day sees to it.
	var show := not unseen(v) and not v.has_meta(InsideView.HIDDEN)
	if v.visible != show:
		v.visible = show


## Straight into bed upstairs without the walk and the climb.
static func _settle(v: Villager) -> void:
	var trip := v.bed_trip
	v.unpose_body()
	trip.erase("hidden")
	trip.step = "upstairs"
	_lie_down(v, trip, true)
	_mind_sight(v)
	v.reset_physics_interpolation()


## Into the bed of the trip, lying under the blanket at once (a game loaded at night, a villager sent home).
static func _lie_down(v: Villager, trip: Dictionary, _at_once: bool) -> void:
	var bed: Dictionary = trip.bed
	var side := _side(v, trip)
	v.bed_pose(BedRise.at(BedRise.TUCK_KEYS, BedRise.TUCK_LENGTH, side), bed.pos, float(bed.rot), side)
	BedBlanket.tuck(v.level, bed.pos, float(bed.rot), true)


## The side of the bed the villager gets in and out by (the same all night).
static func _side(v: Villager, trip: Dictionary) -> float:
	if not trip.has("side"):
		var bed: Dictionary = trip.bed
		trip["side"] = BedRise.choose_side(v.level, bed.pos, float(bed.rot), bed.stand, [v.get_rid()])
	return float(trip.side)


## Starts the climb up (`up`) or down the house's ladder from where the villager stands.
static func _start_climb(v: Villager, trip: Dictionary, up: bool) -> void:
	var house: Dictionary = trip.house
	var edge: Vector3 = house.ladder_edge
	var push: Vector3 = house.ladder_push
	var from := v.global_position - edge
	from.y = 0.0
	var tall: float = house.ladder_tall
	trip["keys"] = LadderPose.up_keys(tall, from.dot(push)) if up else LadderPose.down_keys(tall, from.dot(push))
	trip["aside"] = from.dot(Vector3(-push.z, 0, push.x))
	trip.t = 0.0
	trip.step = "climb" if up else "climb_down"
	v.rotation.y = atan2(push.x, push.z)


## One tick on the ladder; true once the climb is done.
static func _climb(v: Villager, trip: Dictionary, delta: float) -> bool:
	var house: Dictionary = trip.house
	var keys: Array = trip["keys"]
	trip.t = float(trip.t) + delta
	var state := LadderPose.at(keys, trip.t)
	var push: Vector3 = house.ladder_push
	var edge: Vector3 = house.ladder_edge
	var side := Vector3(-push.z, 0, push.x)
	var height := float(state.height)
	v.global_position = Vector3(edge.x, edge.y, edge.z) + push * float(state.forward) \
			+ side * float(trip.get("aside", 0.0)) * float(state.side) + Vector3(0, height, 0)
	v.rotation.y = atan2(push.x, push.z)
	v.pose_body(state.pose)
	# Seen from below until the head is through the hatch; from above all the way.
	trip["hidden"] = height > float(house.ladder_tall) - HIDDEN_BELOW and not _hero_up(v, trip)
	_mind_sight(v)
	return trip.t >= LadderPose.length(keys)


## One physics tick of the way to bed or out of the house.
static func step(v: Villager, delta: float) -> void:
	var trip := v.bed_trip
	if trip.is_empty():
		return
	# The home task runs on while the trip lasts.
	v.keep_task(10.0)
	trip.clock = float(trip.clock) + delta
	match String(trip.step):
		"in", "out":
			if _walk(v, trip, delta):
				if trip.step == "out":
					_done(v)
				elif _on_ground(trip.house, trip.bed):
					trip.step = "to_bed"
					trip.way = [trip.bed.stand]
					trip.clock = 0.0
				else:
					_start_climb(v, trip, true)
		"climb":
			if _climb(v, trip, delta):
				v.unpose_body()
				v.play("Idle", 0.15)
				trip.erase("hidden")
				trip.step = "to_bed"
				trip.way = [trip.bed.stand]
				trip.clock = 0.0
		"to_bed":
			if _walk(v, trip, delta):
				trip.step = "to_side"
				trip.t = 0.0
				trip["from"] = v.global_position
		"to_side":
			# A few steps from where the walk ended to the floor beside the bed.
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / SIDE_TIME)
			var side := _side(v, trip)
			var spot := BedRise.beside(trip.bed.pos, float(trip.bed.rot), side)
			spot.y = (trip.from as Vector3).y
			v.global_position = (trip.from as Vector3).lerp(spot, k)
			v.face_way(spot - v.global_position, delta)
			v.play("Walking_A", 0.1)
			if k >= 1.0:
				trip.step = "tuck"
				trip.t = 0.0
				trip.erase("covered")
		"tuck":
			trip.t = float(trip.t) + delta
			var side := _side(v, trip)
			var bed: Dictionary = trip.bed
			v.bed_pose(BedRise.at(BedRise.TUCK_KEYS, float(trip.t), side), bed.pos, float(bed.rot), side)
			if float(trip.t) >= BedRise.BLANKET_ON_AT and not trip.has("covered"):
				trip["covered"] = true
				BedBlanket.tuck(v.level, bed.pos, float(bed.rot))
			if float(trip.t) >= TUCK_TIME:
				trip.step = "asleep" if _on_ground(trip.house, bed) else "upstairs"
		"upstairs":
			pass
		"rise":
			trip.t = float(trip.t) + delta
			var side := _side(v, trip)
			var bed: Dictionary = trip.bed
			v.bed_pose(BedRise.at(BedRise.RISE_KEYS, float(trip.t), side), bed.pos, float(bed.rot), side)
			if float(trip.t) >= BedRise.BLANKET_OFF_AT and not trip.has("thrown"):
				trip["thrown"] = true
				BedBlanket.push_off(v.level, bed.pos, float(bed.rot))
			if float(trip.t) >= BedRise.YAWN_AT and not trip.has("yawned"):
				trip["yawned"] = true
				Sfx.play(v, "yawn", -8.0, v.global_position)
			if float(trip.t) >= RISE_TIME:
				v.bed_pose_end(BedRise.beside(bed.pos, float(bed.rot), side), Vector3.ZERO)
				trip.step = "to_stand"
				trip.t = 0.0
				trip["from"] = v.global_position
		"to_stand":
			# A few steps from the floor beside the bed to where the way on begins.
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / SIDE_TIME)
			var stand: Vector3 = trip.bed.stand
			v.global_position = (trip.from as Vector3).lerp(stand, k)
			v.face_way(stand - v.global_position, delta)
			v.play("Walking_A", 0.1)
			if k >= 1.0:
				v.play("Idle", 0.15)
				if _on_ground(trip.house, trip.bed):
					_go_out(v, trip)
				else:
					trip.step = "to_hatch"
					trip.way = [trip.house.ladder_top]
					trip.clock = 0.0
		"to_hatch":
			if _walk(v, trip, delta):
				_start_climb(v, trip, false)
		"climb_down":
			if _climb(v, trip, delta):
				v.unpose_body()
				v.play("Idle", 0.15)
				v.reset_physics_interpolation()
				_go_out(v, trip)
	_mind_sight(v)


## The morning: out of bed, to the hatch, down the ladder and out of the door. Returns whether the
## villager was in a house one walks into (and is on the way out now).
static func rise(v: Villager) -> bool:
	var trip := v.bed_trip
	if trip.is_empty():
		return false
	trip.t = 0.0
	trip.clock = 0.0
	match String(trip.step):
		"upstairs", "asleep", "to_side", "tuck":
			trip.step = "rise"
			trip.erase("thrown")
			trip.erase("yawned")
		"climb", "to_bed":
			# Not in bed yet: straight back down from the top of the ladder.
			v.unpose_body()
			v.global_position = trip.house.ladder_top
			v.reset_physics_interpolation()
			_start_climb(v, trip, false)
		"rise", "to_stand", "to_hatch", "climb_down":
			pass
		_:
			_go_out(v, trip)
	return true


static func _go_out(v: Villager, trip: Dictionary) -> void:
	var walk_in: WalkIn = v.level.get("walk_in")
	var way := walk_in.door_points(trip.house)
	var inner: Array = (trip.house.get("inner_way", []) as Array).duplicate()
	inner.reverse()
	trip.way = inner + [way[1], way[0], _approach(way)]
	trip.step = "out"
	trip.clock = _slack(v.global_position, trip.way)
	trip.erase("hidden")
	_free(trip)


## Out of the house at once, onto the street before its door (a mason called to the wall, a fright).
static func leave_at_once(v: Villager) -> void:
	var trip := v.bed_trip
	if trip.is_empty():
		return
	var walk_in: WalkIn = v.level.get("walk_in")
	v.global_position = walk_in.door_points(trip.house)[0]
	v.reset_physics_interpolation()
	v.visible = true
	if not (trip.get("bed", {}) as Dictionary).is_empty() and String(trip.step) in ["tuck", "upstairs", "asleep", "rise"]:
		BedBlanket.push_off(v.level, trip.bed.pos, float(trip.bed.rot), true)
	v.bed_pose_end(walk_in.door_points(trip.house)[0], Vector3.ZERO)
	v.play("Idle", 0.1)
	_free(trip)
	v.bed_trip = {}


## A point straight out from the doorway, in line with its middle: whoever goes in turns the corner
## there and walks through the doorway square on, and whoever comes out walks on to it before
## turning away, so nobody cuts across the door frame (see `way` = WalkIn.door_points).
const APPROACH := 1.3


static func _approach(way: Array) -> Vector3:
	var out: Vector3 = way[0] - way[1]
	out.y = 0.0
	return way[0] + out.normalized() * APPROACH


## The clock a leg starts at: negative for a long way (a tower with three floors), so that GIVE_UP
## counts the time a walk takes beyond what its length needs.
static func _slack(from: Vector3, way: Array) -> float:
	var length := 0.0
	var at := from
	for p: Vector3 in way:
		length += Vector2(p.x - at.x, p.z - at.z).length()
		at = p
	return -maxf(0.0, length / Villager.WALK_SPEED - GIVE_UP * 0.5)


static func _free(trip: Dictionary) -> void:
	var bed: Dictionary = trip.get("bed", {})
	if not bed.is_empty():
		bed.by = null


## Out of the door: back to the day (see Villager.out_of_bed).
static func _done(v: Villager) -> void:
	_free(v.bed_trip)
	v.bed_trip = {}
	v.out_of_bed()


## Walks the trip's way one tick: along the points, the feet on the floor (the ramp, the boards),
## pushing the door open on the way. True once the last point is reached.
static func _walk(v: Villager, trip: Dictionary, delta: float) -> bool:
	var way: Array = trip.way
	if way.is_empty():
		return true
	var walk_in: WalkIn = v.level.get("walk_in")
	var goal: Vector3 = way[0]
	var to := goal - v.global_position
	to.y = 0.0
	var pace := v.walk_stride(delta)
	if to.length() <= maxf(pace, ARRIVE) or trip.clock > GIVE_UP:
		# The feet's height tells a floor from the one over it (see WalkIn.floor_at).
		var at := Vector3(goal.x, v.global_position.y, goal.z)
		at.y = walk_in.floor_at(at)
		v.global_position = at
		way.pop_front()
		if trip.clock > GIVE_UP:
			way.clear()
		return way.is_empty()
	var next := v.global_position + to.normalized() * pace
	next.y = walk_in.floor_at(next)
	v.global_position = next
	v.face_way(to, delta)
	var door: Vector3 = (trip.house.node as Node3D).global_transform * (trip.house.door as Vector3)
	if not String(trip.step) in UPSTAIRS and Vector2(door.x - next.x, door.z - next.z).length() < DOOR_PUSH:
		var leaf = trip.house.get("leaf")
		if leaf != null and is_instance_valid(leaf):
			# Open while someone is at it, shut again a moment after they have gone through.
			(leaf as HouseDoor).keep_open(DOOR_HOLD)
	return false

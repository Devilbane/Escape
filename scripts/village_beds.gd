class_name VillageBeds
extends RefCounted
## The villagers go to bed in the houses one can walk into (see WalkIn). At nightfall a villager who
## sleeps walks home as before; at the door they now step in, walk to the ladder by the side wall
## and climb it, hand over hand and foot over foot the way the hero climbs (see LadderPose), up
## through the hatch to the room on the floor above (see WalkIn._furnish_upstairs). There they walk
## to their bed, hop in and sleep. Two beds to a house at most (WalkIn.MAX_BEDS): a villager whose
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
const UPSTAIRS := ["to_bed", "hop", "upstairs", "rise", "hop_down", "to_hatch"]
## Seconds: the hop onto the bed or down from it, and how long getting up takes.
const HOP_TIME := 0.45
const RISE_TIME := 2.2
## On the ladder a villager is out of sight from below while their feet are higher than this below
## the hatch (metres): the head is through it.
const HIDDEN_BELOW := 1.2
## How near a path point counts as reached (metres), and how near the door it gets pushed open.
const ARRIVE := 0.15
const DOOR_PUSH := 2.6
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
	var house := walk_in.house_near(v.global_position)
	if house.is_empty():
		return false
	var bed := _free_bed(house)
	if bed.is_empty():
		return false
	var way := walk_in.door_points(house)
	bed.by = v
	v.bed_trip = {"house": house, "bed": bed, "step": "in", "way": [way[0], way[1], house.ladder], "t": 0.0, "clock": 0.0}
	if at_once:
		_settle(v)
	return true


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


## Whether the villager is out of sight at home: in the house the old way, upstairs while the hero
## is not, or on the ladder with the head through the hatch.
static func unseen(v: Villager) -> bool:
	var trip := v.bed_trip
	if trip.is_empty():
		return true
	if String(trip.step) in UPSTAIRS:
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


## Into the bed of the trip: at once (`at_once`) or with the clip.
static func _lie_down(v: Villager, trip: Dictionary, at_once: bool) -> void:
	var bed: Dictionary = trip.bed
	v.global_position = Level.lie_spot(bed.pos, float(bed.rot), v.body_scale())
	# Lying down falls backwards: face the foot of the bed.
	v.rotation.y = float(bed.rot)
	if at_once:
		v.play("Lie_Down", 0.0)
		v.anim_to_end()
		v.lean_on_pillow(true)
	else:
		v.play("Lie_Down", 0.15)
		v.lean_on_pillow(true, 0.9)


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
				trip.step = "hop"
				trip.t = 0.0
				trip["from"] = v.global_position
		"hop":
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / HOP_TIME)
			var spot := Level.lie_spot(trip.bed.pos, float(trip.bed.rot), v.body_scale())
			v.global_position = (trip.from as Vector3).lerp(spot, k) + Vector3(0, sin(k * PI) * 0.5, 0)
			v.play("Idle", 0.1)
			if k >= 1.0:
				_lie_down(v, trip, false)
				trip.step = "upstairs"
		"upstairs":
			pass
		"rise":
			trip.t = float(trip.t) + delta
			if trip.t >= RISE_TIME:
				trip.step = "hop_down"
				trip.t = 0.0
				trip["from"] = v.global_position
		"hop_down":
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / HOP_TIME)
			var stand: Vector3 = trip.bed.stand
			v.global_position = (trip.from as Vector3).lerp(stand, k) + Vector3(0, sin(k * PI) * 0.4, 0)
			v.play("Idle", 0.15)
			if k >= 1.0:
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
		"upstairs", "hop":
			v.play("Lie_StandUp", 0.2)
			v.lean_on_pillow(false, 0.4)
			trip.step = "rise"
		"climb", "to_bed":
			# Not in bed yet: straight back down from the top of the ladder.
			v.unpose_body()
			v.global_position = trip.house.ladder_top
			v.reset_physics_interpolation()
			_start_climb(v, trip, false)
		"rise", "hop_down", "to_hatch", "climb_down":
			pass
		_:
			_go_out(v, trip)
	return true


static func _go_out(v: Villager, trip: Dictionary) -> void:
	var walk_in: WalkIn = v.level.get("walk_in")
	var way := walk_in.door_points(trip.house)
	trip.way = [way[1], way[0]]
	trip.step = "out"
	trip.clock = 0.0
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
	v.unpose_body()
	v.lean_on_pillow(false)
	v.play("Idle", 0.1)
	_free(trip)
	v.bed_trip = {}


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
		var at := goal
		at.y = walk_in.floor_at(goal)
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
		if leaf != null and is_instance_valid(leaf) and not (leaf as HouseDoor).is_open():
			(leaf as HouseDoor).swing()
	return false

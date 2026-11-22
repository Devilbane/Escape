class_name VillageBeds
extends RefCounted
## The villagers go to bed in the houses one can walk into (see WalkIn). At nightfall a villager who
## sleeps walks home as before; at the door they now step in, walk to the ladder in the front corner
## and climb it, hand over hand and foot over foot the way the hero climbs a built ladder (see
## LadderPose), up through the hatch to the floor above, where the beds are (see
## WalkIn._furnish_house): three at most to a house, to whoever comes first, the rest sleep up there
## all the same. Once their head is through the hatch they are gone from sight until the morning.
## In the morning they climb down, hop off the last rungs, walk out of the door and go back to their
## day.
##
## Called by Villager: `enter` from Villager._hide_inside when they reach the door at nightfall,
## `step` every physics tick of their "home" task, `rise` when the morning comes (see
## Villager._come_out) and `leave_at_once` when anything else calls them out in a hurry (the
## mason to a broken wall, a fright). A villager's trip is kept on them (Villager.bed_trip).
## With WalkIn.houses off there are no houses to walk into, `enter` says no and the villagers
## vanish at the door as they always did.

## On the ladder a villager is out of sight while their feet are higher than this below the hatch
## (metres): the head is through it.
const HIDDEN_BELOW := 1.2
## How near a path point counts as reached (metres), and how near the door it gets pushed open.
const ARRIVE := 0.15
const DOOR_PUSH := 2.6
## The longest a walk inside may take before the villager is simply put where they were going
## (something in the way), seconds.
const GIVE_UP := 20.0


## Starts a villager's way to bed in the house nearest to them. With `at_once` they are in bed (or
## upstairs) at once: a game loaded at night, a villager sent home on the spot. False when there is
## no house to walk into nearby: they go in the old way.
static func enter(v: Villager, at_once: bool) -> bool:
	var walk_in: WalkIn = v.level.get("walk_in") if v.level != null else null
	if walk_in == null:
		return false
	var house := walk_in.house_near(v.global_position, 9.0, v.role)
	if house.is_empty():
		return false
	var bed := _free_bed(house)
	var way := walk_in.door_points(house)
	if not bed.is_empty():
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


## Whether the villager is out of sight at home: in the house the old way, upstairs, or on the
## ladder with the head through the hatch.
static func unseen(v: Villager) -> bool:
	return v.bed_trip.is_empty() or v.bed_trip.step == "upstairs" or bool(v.bed_trip.get("hidden", false))


## Straight upstairs without the walk and the climb: in bed, or by the hatch when no bed is left.
static func _settle(v: Villager) -> void:
	var trip := v.bed_trip
	var bed: Dictionary = trip.bed
	v.unpose_body()
	v.lean_on_pillow(false)
	if bed.is_empty():
		v.global_position = trip.house.ladder_top
		v.play("Idle", 0.0)
	else:
		v.global_position = Level.lie_spot(bed.pos, float(bed.rot), v.body_scale())
		v.rotation.y = float(bed.rot)
		v.play("Lie_Down", 0.0)
		v.anim_to_end()
	v.visible = false
	trip.step = "upstairs"
	trip.erase("hidden")
	v.reset_physics_interpolation()


## Starts the climb up (`up`) or down the house's ladder from where the villager stands.
static func _start_climb(v: Villager, trip: Dictionary, up: bool) -> void:
	var house: Dictionary = trip.house
	var edge: Vector3 = house.ladder_edge
	var push: Vector3 = house.ladder_push
	var from := v.global_position - edge
	from.y = 0.0
	var tall: float = house.ladder_tall
	trip["keys"] = LadderPose.up_keys(tall, from.dot(push)) if up else LadderPose.down_keys(tall, LadderPose.TOP_FORWARD)
	trip["aside"] = from.dot(Vector3(-push.z, 0, push.x)) if up else 0.0
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
	var hidden := height > float(house.ladder_tall) - HIDDEN_BELOW
	if hidden != bool(trip.get("hidden", false)):
		trip["hidden"] = hidden
		# Back in sight only where the walls let the hero see (see InsideView).
		v.visible = not hidden and not v.has_meta(InsideView.HIDDEN)
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
				_settle(v)
		"upstairs":
			pass
		"climb_down":
			if _climb(v, trip, delta):
				v.unpose_body()
				v.play("Idle", 0.15)
				v.reset_physics_interpolation()
				_go_out(v, trip)


## The morning: down the ladder and out of the door. Returns whether the villager was in a house one
## walks into (and is on the way out now).
static func rise(v: Villager) -> bool:
	var trip := v.bed_trip
	if trip.is_empty():
		return false
	trip.clock = 0.0
	match String(trip.step):
		"upstairs", "climb":
			v.lean_on_pillow(false)
			v.global_position = trip.house.ladder_top
			v.reset_physics_interpolation()
			trip["hidden"] = true
			v.visible = false
			_start_climb(v, trip, false)
		"climb_down":
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
		var at := Vector3(goal.x, 0, goal.z)
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
	if Vector2(door.x - next.x, door.z - next.z).length() < DOOR_PUSH:
		var leaf = trip.house.get("leaf")
		if leaf != null and is_instance_valid(leaf) and not (leaf as HouseDoor).is_open():
			(leaf as HouseDoor).swing()
	return false

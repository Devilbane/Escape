class_name VillageBeds
extends RefCounted
## The villagers go to bed in the houses one can walk into (see WalkIn). At nightfall a villager who
## sleeps walks home as before; at the door they now step in, walk to a free bed, hop onto it and lie
## down, and stay there all night where the hero can see them through the door or from inside. The
## beds go to whoever comes first: three to a house, and whoever finds them all taken climbs the
## ladder to the floor above and is gone from sight until the morning. In the morning they get up
## (or climb down), walk out of the door and go back to their day.
##
## Called by Villager: `enter` from Villager._hide_inside when they reach the door at nightfall,
## `step` every physics tick of their "home" task, `rise` when the morning comes (see
## Villager._come_out) and `leave_at_once` when anything else calls them out in a hurry (the
## mason to a broken wall, a fright). A villager's trip is kept on them (Villager.bed_trip).
## With WalkIn.houses off there are no houses to walk into, `enter` says no and the villagers
## vanish at the door as they always did.

## Seconds: the hop onto the bed or down from it, climbing the ladder up or down, and how long the
## getting up takes.
const HOP_TIME := 0.45
const CLIMB_TIME := 1.4
const RISE_TIME := 2.2
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
	var goal: Vector3 = bed.stand if not bed.is_empty() else house.ladder
	if not bed.is_empty():
		bed.by = v
	v.bed_trip = {"house": house, "bed": bed, "step": "in", "way": [way[0], way[1], goal], "t": 0.0, "clock": 0.0}
	if at_once:
		_settle(v)
	return true


static func _free_bed(house: Dictionary) -> Dictionary:
	for bed: Dictionary in house.beds:
		var by = bed.get("by")
		if by == null or not is_instance_valid(by) or not is_same((by as Villager).bed_trip.get("bed"), bed):
			return bed
	return {}


## Whether the villager is out of sight at home: in the house the old way, or up the ladder.
static func unseen(v: Villager) -> bool:
	return v.bed_trip.is_empty() or v.bed_trip.step == "upstairs"


## Straight into bed (or up the ladder) without the walk.
static func _settle(v: Villager) -> void:
	var trip := v.bed_trip
	var bed: Dictionary = trip.bed
	if bed.is_empty():
		v.global_position = trip.house.ladder_top
		v.visible = false
		trip.step = "upstairs"
	else:
		v.global_position = _lie_spot(v, bed)
		v.rotation.y = float(bed.rot)
		v.play("Lie_Down", 0.0)
		v.anim_to_end()
		v.lean_on_pillow(true)
		trip.step = "asleep"
	v.reset_physics_interpolation()


## Where the villager lies, the head on the pillows (the hero lies the same way, see Level.lie_spot).
static func _lie_spot(v: Villager, bed: Dictionary) -> Vector3:
	return Level.lie_spot(bed.pos, float(bed.rot), v.body_scale())


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
				elif trip.bed.is_empty():
					trip.step = "climb"
					trip.t = 0.0
					trip["from"] = v.global_position
				else:
					trip.step = "hop"
					trip.t = 0.0
					trip["from"] = v.global_position
		"hop":
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / HOP_TIME)
			var spot := _lie_spot(v, trip.bed)
			v.global_position = (trip.from as Vector3).lerp(spot, k) + Vector3(0, sin(k * PI) * 0.5, 0)
			v.play("Idle", 0.1)
			if k >= 1.0:
				# Lying down falls backwards: face the foot of the bed.
				v.rotation.y = float(trip.bed.rot)
				v.play("Lie_Down", 0.15)
				v.lean_on_pillow(true, 0.9)
				trip.step = "asleep"
		"asleep":
			pass
		"climb":
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / CLIMB_TIME)
			v.global_position = (trip.from as Vector3).lerp(trip.house.ladder_top, k)
			v.play("Idle", 0.2)
			if k >= 1.0:
				v.visible = false
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
				_go_out(v, trip)
		"climb_down":
			trip.t = float(trip.t) + delta
			var k := minf(1.0, trip.t / CLIMB_TIME)
			v.global_position = (trip.house.ladder_top as Vector3).lerp(trip.house.ladder, k)
			v.play("Idle", 0.2)
			if k >= 1.0:
				_go_out(v, trip)


## The morning: up out of bed (or down the ladder) and out of the door. Returns whether the villager
## was in a house one walks into (and is on the way out now).
static func rise(v: Villager) -> bool:
	var trip := v.bed_trip
	if trip.is_empty():
		return false
	trip.t = 0.0
	trip.clock = 0.0
	match String(trip.step):
		"asleep", "hop":
			v.play("Lie_StandUp", 0.2)
			v.lean_on_pillow(false, 0.4)
			trip.step = "rise"
		"upstairs", "climb":
			v.visible = true
			v.global_position = trip.house.ladder_top
			v.reset_physics_interpolation()
			trip.step = "climb_down"
		_:
			_go_out(v, trip)
	return true


static func _go_out(v: Villager, trip: Dictionary) -> void:
	var walk_in: WalkIn = v.level.get("walk_in")
	var way := walk_in.door_points(trip.house)
	trip.way = [way[1], way[0]]
	trip.step = "out"
	trip.clock = 0.0
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

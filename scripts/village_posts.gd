class_name VillagePosts
extends RefCounted
## Villagers who keep a hall (see VillageHalls.KEEPERS) work inside it by day: the shopkeeper behind
## her counter in the shop, the clerk at his desk in the Crown office, the guild master at hers in
## the guildhall. Where such a villager's hall can be walked into,
## she walks in through the door to her place behind the counter, works there facing the door, and
## walks out again at nightfall (or when the alarm sounds); anything else that calls her away
## while she is inside (a fright, a slime) puts her out on the street before the door at once.
## The hero trades with her across the counter: her station is touched from in front of it.
##
## Called by Villager: `wants` and `enter` from its day's plan, `step` every physics tick of its
## "post" task, `leave_at_once` when another task starts, `mind_station` each tick.
## With the hall switched off (WalkIn.halls) there is no counter and she stands outside as before.

## From how far (metres, to her) the hero standing before the counter reaches her.
const TOUCH := 2.2
## How near a way point counts as reached (metres), and the longest the walk may take (seconds)
## before she is simply put where she was going.
const ARRIVE := 0.15
const GIVE_UP := 15.0
## Behind the counter a keeper stands still and busies their hands only now and then: every so
## many seconds (from, to), for this long.
const FIDGET_EVERY := Vector2(7.0, 14.0)
const FIDGET_TIME := 2.0


## The post of the hall the villager keeps, or {} (she keeps none, or it cannot be walked into).
static func post_of(v: Villager) -> Dictionary:
	var kind := VillageHalls.kept_by(v.role)
	if kind == "" or v.level == null:
		return {}
	var walk_in: WalkIn = v.level.get("walk_in")
	if walk_in == null:
		return {}
	for rec in walk_in.buildings:
		if rec.kind == kind and rec.get("opened", false) and not (rec.get("posts", []) as Array).is_empty():
			return {"rec": rec, "post": rec.posts[0]}
	return {}


## Whether the villager should go to her post now: she keeps a hall and the day is calm.
static func wants(v: Villager) -> bool:
	return not v.night and not v.level.village_alarm.raised and not post_of(v).is_empty()


## Sets off in through the door to her place behind the counter.
static func enter(v: Villager) -> void:
	var found := post_of(v)
	if found.is_empty():
		return
	var walk_in: WalkIn = v.level.get("walk_in")
	var way := walk_in.door_points(found.rec)
	var post: Dictionary = found.post
	v.post_trip = {"rec": found.rec, "post": post, "step": "in", "way": [way[0], way[1], post.pos], "clock": 0.0}
	_pass_through(v, true)


## Whether she is in the hall (on the way in, at her place or on the way out).
static func inside(v: Villager) -> bool:
	return not v.post_trip.is_empty()


## Whether she is at her place in the hall (not on the way in or out).
static func at_post(v: Villager) -> bool:
	return not v.post_trip.is_empty() and v.post_trip.step == "at"


## One physics tick of the "post" task.
static func step(v: Villager, delta: float) -> void:
	var trip := v.post_trip
	if trip.is_empty():
		v.end_post()
		return
	v.keep_task(10.0)
	trip.clock = float(trip.clock) + delta
	match String(trip.step):
		"in":
			if _walk(v, trip, delta):
				trip.step = "at"
				_pass_through(v, false)
		"at":
			v.turn_toward(Basis(Vector3.UP, float(trip.post.rot)) * Vector3.BACK, delta)
			# She stands calmly behind her counter and only now and then busies her hands.
			trip["fidget"] = float(trip.get("fidget", FIDGET_EVERY.x)) - delta
			if float(trip.fidget) <= 0.0:
				trip.fidget = randf_range(FIDGET_EVERY.x, FIDGET_EVERY.y)
				trip["busy"] = FIDGET_TIME
			trip["busy"] = float(trip.get("busy", 0.0)) - delta
			v.play(v.work_anim() if float(trip.busy) > 0.0 else "Idle")
			if v.night or v.level.village_alarm.raised:
				_go_out(v, trip)
		"out":
			if _walk(v, trip, delta):
				v.post_trip = {}
				_pass_through(v, false)
				v.end_post()


static func _go_out(v: Villager, trip: Dictionary) -> void:
	var walk_in: WalkIn = v.level.get("walk_in")
	var way := walk_in.door_points(trip.rec)
	trip.way = [way[1], way[0]]
	trip.step = "out"
	trip.clock = 0.0
	_pass_through(v, true)


## Out on the street before the door at once (called away inside the hall by a fright, a slime).
static func leave_at_once(v: Villager) -> void:
	var trip := v.post_trip
	if trip.is_empty():
		return
	var walk_in: WalkIn = v.level.get("walk_in")
	v.global_position = walk_in.door_points(trip.rec)[0]
	v.reset_physics_interpolation()
	v.post_trip = {}
	_pass_through(v, false)


## Behind her counter the hero reaches her from in front of it, not only on her own tile.
static func mind_station(v: Villager) -> void:
	if v.station.is_empty():
		return
	if not v.post_trip.is_empty() and v.post_trip.step == "at":
		v.station["touch"] = TOUCH
	else:
		v.station.erase("touch")


## On the way through the door the keeper does not bump into the hero (no body to collide with),
## so the two never block each other in the doorway; at their place and outside they have it again.
static func _pass_through(v: Villager, through: bool) -> void:
	if through:
		if v.collision_layer != 0:
			v.set_meta("post_layer", v.collision_layer)
			v.collision_layer = 0
	elif v.has_meta("post_layer"):
		v.collision_layer = int(v.get_meta("post_layer"))
		v.remove_meta("post_layer")


## Walks the trip's way one tick, the feet on the floor, pushing the door open on the way. True
## once the last point is reached.
static func _walk(v: Villager, trip: Dictionary, delta: float) -> bool:
	var way: Array = trip.way
	if way.is_empty():
		return true
	var walk_in: WalkIn = v.level.get("walk_in")
	var goal: Vector3 = way[0]
	var to := goal - v.global_position
	to.y = 0.0
	var pace := v.walk_stride(delta)
	if to.length() <= maxf(pace, ARRIVE) or float(trip.clock) > GIVE_UP:
		var at := Vector3(goal.x, 0, goal.z)
		at.y = walk_in.floor_at(at)
		v.global_position = at
		way.pop_front()
		if float(trip.clock) > GIVE_UP:
			way.clear()
			v.reset_physics_interpolation()
		return way.is_empty()
	var next := v.global_position + to.normalized() * pace
	next.y = walk_in.floor_at(next)
	v.global_position = next
	v.face_way(to, delta)
	v.play("Walking_A")
	var rec: Dictionary = trip.rec
	var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
	if Vector2(door.x - next.x, door.z - next.z).length() < VillageBeds.DOOR_PUSH:
		var leaf = rec.get("leaf")
		if leaf != null and is_instance_valid(leaf) and not (leaf as HouseDoor).is_open():
			(leaf as HouseDoor).swing()
	return false

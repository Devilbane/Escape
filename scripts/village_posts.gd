class_name VillagePosts
extends RefCounted
## Villagers who keep a hall (see VillageHalls.KEEPERS) work inside it by day: the shopkeeper behind
## her counter in the shop, the clerk at his desk in the Crown office, the guild master at hers in
## the guildhall, and the banker at his desk in the bank's hall (see BankHall, which brings its own
## way in and out). Where such a villager's hall can be walked into,
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
	if v.role == BankHall.KEEPER:
		# The banker at his desk in the bank's hall (see BankHall).
		return BankHall.post(v.level)
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


## Whether the hall `rec` is locked: it has a keeper (see VillageHalls.KEEPERS) who is not inside it
## and awake (not on the way in, at her place or on the way out). Halls without a keeper, or that
## cannot be walked into at a counter, stay open.
static func locked(level: Node, rec: Dictionary) -> bool:
	var role: String = VillageHalls.KEEPERS.get(String(rec.get("kind", "")), "")
	if role == "" or (rec.get("posts", []) as Array).is_empty():
		return false
	var people = level.get("villagers")
	if people == null:
		return false
	for v: Villager in people:
		if v.role == role:
			return v.post_trip.is_empty() or v.post_trip.get("rec") != rec
	return false


## Whether the villager should go to her post now: she keeps a hall and the day is calm.
static func wants(v: Villager) -> bool:
	return not v.night and not v.level.village_alarm.raised and not post_of(v).is_empty()


## Sets off in through the door to her place behind the counter.
static func enter(v: Villager) -> void:
	var found := post_of(v)
	if found.is_empty():
		return
	var way := _door_points(v, found.rec)
	var post: Dictionary = found.post
	v.post_trip = {"rec": found.rec, "post": post, "step": "in", "way": [way[0], way[1]] + found.rec.get("via", []) + [post.pos], "clock": 0.0}
	_pass_through(v, true)


## Sets a guest off in through the door of the hall `rec` to the seat `seat` ({"pos", "rot", ...}),
## where they sit for `stay` seconds (see TavernBrewer: Fritz at the tavern's table). The guest
## leaves at nightfall or the alarm like a keeper, and on their own when the time is up.
static func enter_guest(v: Villager, rec: Dictionary, seat: Dictionary, stay: float) -> void:
	var way := _door_points(v, rec)
	v.post_trip = {"rec": rec, "post": seat, "step": "in", "way": [way[0], way[1], seat.pos], "clock": 0.0,
			"guest": true, "stay": stay}
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
			if trip.get("guest", false):
				if v.night or v.level.village_alarm.raised or TavernBrewer.guest_step(v, trip, delta):
					_go_out(v, trip)
				return
			if v.night or v.level.village_alarm.raised:
				v.hold_mug(false)
				trip["serve"] = ""
			elif v.role == TavernBrewer.BREWER and TavernBrewer.keeper_step(v, trip, delta):
				return
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
	TavernBrewer.tidy(trip)
	var way := _door_points(v, trip.rec)
	var via: Array = (trip.rec.get("via", []) as Array).duplicate()
	via.reverse()
	trip.way = via + [way[1], way[0]]
	trip.step = "out"
	trip.clock = 0.0
	_pass_through(v, true)


## Out on the street before the door at once (called away inside the hall by a fright, a slime).
static func leave_at_once(v: Villager) -> void:
	var trip := v.post_trip
	if trip.is_empty():
		return
	TavernBrewer.tidy(trip)
	v.hold_mug(false)
	v.global_position = _door_points(v, trip.rec)[0]
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
		at.y = _floor_at(walk_in, trip.rec, at)
		v.global_position = at
		way.pop_front()
		if float(trip.clock) > GIVE_UP:
			way.clear()
			v.reset_physics_interpolation()
		return way.is_empty()
	var next := v.global_position + to.normalized() * pace
	next.y = _floor_at(walk_in, trip.rec, next)
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


## The points outside and inside the door of the hall: a record that brings its own (the bank, see
## BankHall) or one of WalkIn's halls.
static func _door_points(v: Villager, rec: Dictionary) -> Array:
	if rec.has("way"):
		return rec.way
	var walk_in: WalkIn = v.level.get("walk_in")
	return walk_in.door_points(rec)


## The floor under a point of the way in or out: the bank's own, or WalkIn's.
static func _floor_at(walk_in: WalkIn, rec: Dictionary, at: Vector3) -> float:
	if rec.get("kind", "") == "bank":
		return BankHall.floor_y(at)
	return walk_in.floor_at(at)

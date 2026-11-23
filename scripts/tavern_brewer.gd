class_name TavernBrewer
extends RefCounted
## Eberhard the brewer keeps the tavern (see VillageHalls.KEEPERS and VillagePosts): by day he works
## behind the bar at the taps, and at nightfall he goes home and locks up, like the other keepers.
##
## Fritz drops in by day. Now and then, when the brewer is at his place, Fritz walks in through
## the tavern's door to his chair at the table by the hearth and sits down (the same way a keeper
## walks to their place, see VillagePosts.enter_guest). A little later the brewer takes a mug from
## the tap, carries it over (the mug shows in his hand), hands it to Fritz (it stands on the table
## then), and stays to chat: the two trade a few lines in their speech bubbles, one at a time. When
## Fritz has had enough he gets up and goes back to his spot outside, and the brewer to the bar.
## Nightfall or an alarm ends it all at once, as for any keeper.
##
## The lines are German with English entries in scripts/lang/tavern_brewer.gd. They are only
## spoken while the hero is within earshot (HEAR_RANGE), so nobody talks to an empty room.

## Who keeps the tavern, and who sits in it (see Villager.ROLES).
const BREWER := "ö"
const GUEST := "5"
## Whether Fritz sets off for the tavern when his day's next task comes up (chance, once per call).
const VISIT_CHANCE := 0.35
## How long he stays seated, at least and at most (seconds), counted from sitting down.
const STAY := Vector2(60.0, 100.0)
## The brewer comes over this long after Fritz sat down (seconds), and the pause after serving
## before a next beer.
const SERVE_AFTER := Vector2(4.0, 7.0)
## Sitting down takes this long (seconds, the animation's length).
const SIT_TIME := 0.9
## How long the hand-over takes (seconds), and how long a line stays up.
const HAND_TIME := 2.2
const LINE_TIME := 3.4
const LINE_GAP := 0.7
## The hero hears them from this far (metres).
const HEAR_RANGE := 16.0
## Fritz sleeps at his table at night, slumped forward with his head in his hands: how far the
## body leans (radians, about the hips) and how far it sinks and moves forward (metres), and how
## often he snores (seconds) and how loud it is (dB).
const SLUMP := 0.75
const SLUMP_DOWN := 0.12
const SLUMP_FORWARD := 0.22
## Over the bar he stands, so he folds further forward.
const COUNTER_SLUMP := 1.0
const COUNTER_FORWARD := 0.05
const SNORE_EVERY := Vector2(3.5, 4.5)
const SNORE_DB := -8.0

## The talk over a beer: each exchange is said in turn, brewer first (German).
const TALKS := [
	["Hier, Fritz. Frisch gezapft.", "Ahh! Das beste Bier diesseits der Berge.", "Das einzige Bier diesseits der Berge."],
	["Dein Deckel ist schon so lang wie der Tresen.", "Ich zahle morgen, Eberhard. Ganz bestimmt.", "Das sagst du seit dem Frühling."],
	["Der Hopfen war dieses Jahr gut.", "Dann bring mir noch einen Krug davon.", "Erst den ersten leeren, Fritz."],
	["Hast du den Helden aus der Gruft gesehen?", "Der trinkt bestimmt gern ein Bier.", "Dann bekommt er meinen besten Krug."],
	["Im Winter schmeckt mein Dunkles am besten.", "Im Sommer schmeckt dein Helles am besten.", "Du trinkst eben alles am besten."],
]


## The tavern's record and Fritz's seat in it ({"rec", "seat"}), or {} when it cannot be walked into.
static func seat_of(level: Node, kind := "table") -> Dictionary:
	var walk_in: WalkIn = level.get("walk_in")
	if walk_in == null:
		return {}
	for rec in walk_in.buildings:
		if rec.kind == "tavern" and rec.get("opened", false):
			for seat: Dictionary in rec.get("seats", []):
				if seat.role == GUEST and seat.get("kind", "table") == kind:
					return {"rec": rec, "seat": seat}
	return {}


## The brewer, or null.
static func brewer_of(level: Node) -> Villager:
	var people = level.get("villagers")
	if people == null:
		return null
	for v: Villager in people:
		if v.role == BREWER:
			return v
	return null


## Whether Fritz should walk into the tavern now: a calm day, the brewer at his place and free.
static func wants(v: Villager) -> bool:
	if v.role != GUEST or v.night or v.level.village_alarm.raised or v.chat_partner != null or v.is_talking():
		return false
	if v.is_frozen() or FrozenFritz.wants(v.level, false) or seat_of(v.level).is_empty():
		return false
	var brewer := brewer_of(v.level)
	if brewer == null or not VillagePosts.at_post(brewer) or not String(brewer.post_trip.get("serve", "")).is_empty():
		return false
	return v._rng.randf() < VISIT_CHANCE


## Sets Fritz off for the tavern: out on the street to the tile before its door first, then in
## through the door to his chair (see arrive). True when he goes.
static func visit(v: Villager) -> bool:
	var found := seat_of(v.level)
	if found.is_empty():
		return false
	var walk_in: WalkIn = v.level.get("walk_in")
	var outside := walk_in.door_points(found.rec)[0]
	if v.level.world_to_cell(v.global_position) == v.level.world_to_cell(outside):
		return arrive(v)
	v.walk_to_then(outside, "tavern")
	return true


## Fritz stands before the door: in he goes to his chair. False when the tavern is gone from under him.
static func arrive(v: Villager) -> bool:
	var found := seat_of(v.level)
	if found.is_empty():
		return false
	VillagePosts.enter_guest(v, found.rec, found.seat, randf_range(STAY.x, STAY.y))
	v.begin_post()
	return true


## Whether Fritz sleeps at his table: it is night and he has sat down for it.
static func sleeping(trip: Dictionary) -> bool:
	return bool(trip.get("sleeping", false))


## At nightfall Fritz does not go home to a bed: he goes in through the tavern's door to his chair
## and sleeps there at the table. True when he goes (see Villager._hide_inside).
static func doze(v: Villager) -> bool:
	if v.role != GUEST or seat_of(v.level).is_empty() or v.level.village_alarm.raised:
		return false
	# One place for the night: slumped at his table, or folded over the bar.
	var found := seat_of(v.level, "counter" if randf() < 0.4 else "table")
	if found.is_empty():
		found = seat_of(v.level)
	VillagePosts.enter_guest(v, found.rec, found.seat, INF)
	v.post_trip["sleeping"] = true
	v.begin_post()
	return true


## Fritz asleep at his table: slumped forward, a snore now and then (heard near him), a "Zzz" rising.
static func sleep_step(v: Villager, trip: Dictionary, delta: float) -> void:
	if trip.post.get("kind", "table") == "counter":
		v.play("Idle")
		v.slump(COUNTER_SLUMP, 0.0, COUNTER_FORWARD)
	else:
		v.play("Sit_Chair_Idle")
		v.slump(SLUMP, SLUMP_DOWN, SLUMP_FORWARD)
	trip["snore_in"] = float(trip.get("snore_in", 1.0)) - delta
	if float(trip.snore_in) > 0.0:
		return
	trip.snore_in = randf_range(SNORE_EVERY.x, SNORE_EVERY.y)
	var hero: Node3D = v.level.player
	if hero == null or hero.global_position.distance_to(v.global_position) > HEAR_RANGE:
		return
	Sfx.play(v.level, "snore", SNORE_DB, v.global_position, 1.0)
	Effects.float_text(v.level, v.global_position + Vector3(0, 1.3, 0), "Zzz", Color(0.75, 0.8, 1.0), true)


## One tick of Fritz at his chair (VillagePosts.step). True once it is time to get up and leave.
static func guest_step(v: Villager, trip: Dictionary, delta: float) -> bool:
	var seat: Dictionary = trip.post
	v.turn_toward(Basis(Vector3.UP, float(seat.rot)) * Vector3.BACK, delta)
	if sleeping(trip):
		# Asleep through the night; up again (stood up like any guest) once it is day.
		if not trip.get("seated", false):
			trip["seated"] = true
			trip["sit_clock"] = 0.0
		trip.sit_clock = float(trip.sit_clock) + delta
		var at_bar: bool = trip.post.get("kind", "table") == "counter"
		if float(trip.sit_clock) < SIT_TIME and not at_bar:
			v.play("Sit_Chair_Down")
			return false
		if not v.night:
			if float(trip.get("rise", -1.0)) < 0.0:
				trip["rise"] = 0.0
				v.slump(0.0, 0.0, 0.0)
			v.play("Idle" if at_bar else "Sit_Chair_StandUp")
			trip.rise = float(trip.rise) + delta
			return float(trip.rise) >= (0.3 if at_bar else SIT_TIME)
		sleep_step(v, trip, delta)
		return false
	if not trip.get("seated", false):
		trip["seated"] = true
		trip["sit_clock"] = 0.0
		trip["serve_in"] = randf_range(SERVE_AFTER.x, SERVE_AFTER.y)
	trip.sit_clock = float(trip.sit_clock) + delta
	if float(trip.get("rise", -1.0)) >= 0.0:
		# Getting up: the standing animation first, then out of the door.
		v.play("Sit_Chair_StandUp")
		trip.rise = float(trip.rise) + delta
		return float(trip.rise) >= SIT_TIME
	if float(trip.sit_clock) < SIT_TIME:
		v.play("Sit_Chair_Down")
	else:
		v.play("Sit_Chair_Idle")
	trip.stay = float(trip.stay) - delta
	if float(trip.stay) <= 0.0 and trip.get("beer", false) and String(_serving(v).get("serve", "")).is_empty():
		trip.rise = 0.0
		_clear_mug(trip)
	return false


## The brewer's trip while he works, or {}.
static func _serving(guest: Villager) -> Dictionary:
	var brewer := brewer_of(guest.level)
	return brewer.post_trip if brewer != null else {}


## A guest on the way out takes the beer off the table (the empty mug is cleared away).
static func tidy(trip: Dictionary) -> void:
	_clear_mug(trip)


static func _clear_mug(trip: Dictionary) -> void:
	var mug = trip.get("mug")
	if mug != null and is_instance_valid(mug):
		(mug as Node3D).visible = false


## One tick of the brewer behind his bar (VillagePosts.step, "at"). True while he is busy with
## Fritz and his usual standing is not to be played; "serve" in his trip says where he is:
## "to" (walking over with the beer), "hand", "chat", "back" (walking to the bar).
static func keeper_step(v: Villager, trip: Dictionary, delta: float) -> bool:
	var stage := String(trip.get("serve", ""))
	var guest := _guest_of(v)
	var guest_trip: Dictionary = guest.post_trip if guest != null else {}
	var seated: bool = not guest_trip.is_empty() and guest_trip.get("guest", false) and guest_trip.get("seated", false) \
			and float(guest_trip.get("sit_clock", 0.0)) >= SIT_TIME and float(guest_trip.get("rise", -1.0)) < 0.0
	if stage == "":
		if not seated or guest_trip.get("beer", false):
			return false
		trip["serve_wait"] = float(trip.get("serve_wait", 0.0)) + delta
		if float(trip.serve_wait) < float(guest_trip.get("serve_in", SERVE_AFTER.x)):
			return false
		trip["serve"] = "to"
		trip["serve_wait"] = 0.0
		v.hold_mug(true)
		return true
	if not seated and stage != "back":
		# Fritz left (or night fell) on the way: put the mug down and go back.
		v.hold_mug(false)
		trip["serve"] = "back"
		return true
	var seat: Dictionary = guest_trip.get("post", {})
	match stage:
		"to":
			if _glide(v, seat.serve, delta):
				trip["serve"] = "hand"
				trip["clock_serve"] = 0.0
		"hand":
			v.turn_toward(seat.pos - v.global_position, delta)
			v.play("Interact")
			trip.clock_serve = float(trip.clock_serve) + delta
			if float(trip.clock_serve) >= HAND_TIME:
				# The beer stands on Fritz's table now.
				v.hold_mug(false)
				guest_trip["beer"] = true
				guest_trip["mug"] = seat.mug
				(seat.mug as Node3D).visible = true
				trip["serve"] = "chat"
				trip["talk"] = {"exchange": randi() % TALKS.size(), "line": 0, "wait": 0.5}
		"chat":
			v.turn_toward(seat.pos - v.global_position, delta)
			v.play("Idle")
			if _chat(v, guest, trip.talk, delta):
				trip["serve"] = "back"
		"back":
			var post: Dictionary = trip.post
			if _glide(v, post.pos, delta):
				trip["serve"] = ""
				trip["serve_wait"] = 0.0
				return false
	return true


static func _guest_of(brewer: Villager) -> Villager:
	var people = brewer.level.get("villagers")
	if people == null:
		return null
	for v: Villager in people:
		if v.role == GUEST:
			return v
	return null


## Walks `v` towards `goal` one tick inside the hall, on its floor. True on arrival.
static func _glide(v: Villager, goal: Vector3, delta: float) -> bool:
	var walk_in: WalkIn = v.level.get("walk_in")
	var to := goal - v.global_position
	to.y = 0.0
	var pace := v.walk_stride(delta)
	if to.length() <= maxf(pace, VillagePosts.ARRIVE):
		v.global_position = Vector3(goal.x, walk_in.floor_at(goal), goal.z)
		return true
	var next := v.global_position + to.normalized() * pace
	next.y = walk_in.floor_at(next)
	v.global_position = next
	v.face_way(to, delta)
	v.play("Walking_A")
	return false


## The exchange over the beer, a line at a time, brewer first. True when it is over.
static func _chat(brewer: Villager, guest: Villager, talk: Dictionary, delta: float) -> bool:
	var lines: Array = TALKS[int(talk.exchange)]
	talk.wait = float(talk.wait) - delta
	if float(talk.wait) > 0.0:
		return false
	if int(talk.line) >= lines.size():
		return true
	var hero: Node3D = brewer.level.player
	var near: bool = hero != null and hero.global_position.distance_to(brewer.global_position) <= HEAR_RANGE
	if not near:
		# Nobody to hear it: the talk keeps its place and waits.
		talk.wait = 1.0
		return false
	if brewer.is_talking() or guest.is_talking():
		return false
	var speaker := brewer if int(talk.line) % 2 == 0 else guest
	var other := guest if speaker == brewer else brewer
	speaker.say(Lang.t(lines[int(talk.line)]), other.global_position, LINE_TIME, true)
	talk.line = int(talk.line) + 1
	talk.wait = LINE_TIME + LINE_GAP
	return false

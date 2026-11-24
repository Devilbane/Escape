class_name TempleMorning
extends RefCounted
## The morning gathering in the temple. Every morning the village walks to the temple (the way in is
## its door, never its walls), sits down on the pews and listens while Priestess Elsbeth, standing
## before the altar and facing them, wishes everyone a good and happy day of work. Then they get up
## one by one, walk out through the door and go on with their day: the shopkeepers to their counters,
## so the shops open only after the service (see VillagePosts.locked), Ilse to her stall at eight.
##
## The hours (see DayNight; an hour is 50 seconds): the call comes at CALL, the speech begins once
## the pews are filled (at SPEECH_FROM at the earliest, at SPEECH_AT whoever is still on the way), and
## whoever sits there is sent off at the latest at END, one by one in a line (EXIT_GAP apart, those
## nearest the door first), before the stalls open.
##
## Everyone who has time goes (see Villager.can_attend), except STAY_AWAY. The pews seat a few
## more than the village holds; someone who finds no seat just carries on with their day.
##
## The walk is the post's walk (see VillagePosts): grid path to the street before the porch, then
## through the door to the aisle, along the gap before the row, down onto the pew. The way out is the
## same way back. Called by Villager: `step` every physics tick of its "service" task, `release` when
## something else calls it away (an alarm, nightfall: out on the porch at once), `finish` at the end.

## The hour the village is called, the earliest and latest start of the speech, and the hour the
## service is over for everyone.
const CALL := 5.9
const SPEECH_FROM := 6.8
const SPEECH_AT := 7.25
const END := 7.95
## Who does not come: the woodcutter (out in the woods), the wandering merchant, the guard on his
## watch and the drinker at the tavern. Elsbeth is the one who speaks (SPEAKER).
const STAY_AWAY := ["3", "%", "4", "5"]
const SPEAKER := "O"
## How much larger her speech bubble is drawn while the hero is inside (see Villager.say).
const BUBBLE_ZOOM := 1.6
## Seconds each line of the speech is up, and the pause after the last one, and how long the
## answers from the pews take before the village gets up.
const LINE_TIME := 5.5
const AMEN_AFTER := 1.2
const AMEN_TIME := 3.0
## How many answer, and the pause between two answers (seconds).
const ANSWERED := 2
const AMEN_GAP := 1.4
## The pause between two leaving the temple, in the order of their seats from the door (seconds).
const EXIT_GAP := 0.6
## How long sitting down and getting up take (seconds).
const SIT_TIME := 0.8
## How long the priestess stands at her place, turning to the pews, before she begins (seconds).
const SETTLE := 1.5
## How often one who was called away on the way (a word, a fright) is sent off again.
const TRIES := 4
## How far before the porch the street tiles one walks to lie at most (metres), and how near the
## porch the villager must be to set off through the door: farther off the grid walk went wrong,
## and they give it up rather than cut through a wall.
const STREET_REACH := 6.0
const NEAR_STREET := 7.5
## How far (metres) the hero may be for the news that the village gathers to reach them.
const NEWS_REACH := 30.0
## How far from the temple's door (metres) a villager still comes: farmers on their far fields do not.
const COME_FROM := 80.0

## The speeches, one is read each day, in turn: three lines each.
const SPEECHES := [
	["Guten Morgen, ihr Lieben! Ein neuer Tag beginnt.",
		"Möge das Licht eure Hände führen und eure Arbeit segnen.",
		"Geht hinaus und habt einen guten, glücklichen Tag!"],
	["Seid gegrüßt, Freunde, und dankt für den Morgen, der uns geschenkt wurde.",
		"Wer heute arbeitet, arbeitet für das ganze Dorf.",
		"Mögen eure Herzen leicht sein und eure Werkstätten voll. Einen gesegneten Tag euch allen!"],
	["Die Nacht ist vorüber, und wir sind alle noch beisammen. Dafür danken wir.",
		"Seid freundlich zueinander und mutig, wenn es nötig ist.",
		"Nun ans Werk! Ich wünsche euch einen guten und frohen Arbeitstag."],
	["Ein neuer Morgen, ein neuer Anfang. Die Götter sehen auf dieses Dorf.",
		"Teilt euer Brot, wenn jemand Hunger hat, und euer Lächeln, wenn jemand traurig ist.",
		"Geht mit leichtem Schritt an eure Arbeit, und kommt am Abend gesund heim!"],
]
## What the pews answer (ANSWERED of them, picked at random).
const ANSWERS := [
	"Amen.",
	"Danke, Elsbeth!",
	"Euch auch, Priesterin!",
	"Möge das Licht mit uns sein.",
	"Gesegneten Tag!",
	"Das tut gut zum Tagesanfang.",
]
const NEWS := "Im Tempel versammelt sich das Dorf zum Morgengebet."

## "idle" until the day's call, then "gather" (walking in and sitting down), "speech" and "leave"
## (the village gets up and goes); idle again for the day when the last is out.
var phase := "idle"
## The seats in the pews (see WalkIn.temple_seats), with each one's "taker" (a Villager or null).
var seats: Array = []
var pulpit := {}
var rec := {}
## The day the gathering was held on; a new one only on another day.
var day := -1
var speaker: Villager = null
var _lines: Array = []
var _spoken := 0
var _clock := 0.0
var _tries := {}
var _answers: Array = []
## Seconds until the line out of the temple is next free (see exit_slot).
var _queue_clock := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## The temple's record in `level`'s walk-in buildings, or {} when it cannot be walked into.
static func temple_of(level: Outdoor) -> Dictionary:
	if level.walk_in == null:
		return {}
	for r: Dictionary in level.walk_in.buildings:
		if r.kind == "temple" and r.get("opened", false):
			return r
	return {}


## Whether `v` is near enough to the temple to come in time: the farmers out on their fields are not.
func near(v: Villager) -> bool:
	var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
	return _flat(v.global_position, door) <= COME_FROM


## Whether `v` takes part at all (not who is able to right now, see Villager.can_attend).
static func goes(v: Villager) -> bool:
	return not v.role in STAY_AWAY and v.role != SPEAKER


## Runs the day's gathering on `level`: calls the village at the hour, sends everyone who is free to a
## seat, starts the speech once they are in, and sends them off when it is over.
func tick(level: Outdoor, delta: float) -> void:
	if level.hour < 0.0 or level.player == null:
		return
	var alarm: bool = level.village_alarm.raised
	_queue_clock = maxf(0.0, _queue_clock - delta)
	if phase == "idle":
		# Whoever is still on the way to a service that is over turns back.
		for v: Villager in level.villagers:
			if v.service_step() == "going":
				v.cancel_service()
		if day != level.day and not level.night and not alarm and level.hour >= CALL and level.hour < SPEECH_AT:
			_begin(level)
		return
	_free_lost_seats()
	if alarm or level.night or level.hour < CALL:
		_send_off(level, false)
		if _nobody_in(level):
			phase = "idle"
		return
	if level.hour >= END:
		phase = "leave"
	match phase:
		"gather":
			_dispatch(level)
			if _ready(level):
				phase = "speech"
				_clock = 0.0
				_spoken = 0
		"speech":
			_dispatch(level)
			_speak(level, delta)
		"leave":
			_send_off(level, true)
			if _nobody_in(level):
				phase = "idle"


## The call: finds the seats and sends Elsbeth to her place before the altar.
func _begin(level: Outdoor) -> void:
	rec = temple_of(level)
	speaker = null
	for v: Villager in level.villagers:
		if v.role == SPEAKER:
			speaker = v
	if rec.is_empty() or speaker == null:
		day = level.day
		return
	day = level.day
	var found: Dictionary = level.walk_in.temple_seats(rec, level.villagers.filter(func(v: Villager) -> bool: return goes(v) and near(v)).size())
	seats = found.seats
	for s: Dictionary in seats:
		s["taker"] = null
	pulpit = found.pulpit
	_tries.clear()
	_lines = SPEECHES[level.day % SPEECHES.size()]
	phase = "gather"
	_clock = 0.0
	_spoken = 0
	if speaker.can_attend():
		speaker.go_to_service(_trip(level, pulpit, true))
	if _flat(level.player.global_position, speaker.global_position) < NEWS_REACH:
		level.notice.emit(Lang.t(NEWS), 3.0)


## The trip a villager walks: the street before the porch, the way through the door and up the
## aisle to the place `spot` (a seat or the pulpit), and the same way back.
func _trip(level: Outdoor, spot: Dictionary, is_speaker: bool) -> Dictionary:
	var node: Node3D = rec.node
	var s := node.scale.x
	var door: Vector3 = rec.door
	var porch := node.global_transform * Vector3(door.x, 0.0, WalkIn.PORCH_END + 1.5 / s)
	var street := _street_near(level, porch, (node.global_transform.basis * Vector3(0, 0, 1)).normalized())
	var points: Array[Vector3] = level.walk_in.door_points(rec)
	var inside := points[1]
	var in_way: Array = [porch, points[0], inside]
	var out_way: Array = []
	if is_speaker:
		in_way.append(spot.stand)
		out_way = [inside, points[0], porch]
	else:
		in_way.append(spot.aisle)
		in_way.append(spot.stand)
		out_way = [spot.aisle, inside, points[0], porch]
	return {"rec": rec, "spot": spot, "speaker": is_speaker, "step": "going", "clock": 0.0, "street": street,
			"in_way": in_way, "out_way": out_way, "way": [], "leave_in": -1.0, "busy": 0.0}


## A street tile (its middle, world) in front of the porch to walk to, a different one for each, so
## the villagers do not all stop on one spot and crowd each other. Only tiles from which the walk
## straight on to the porch crosses open ground: the door is the only way in.
func _street_near(level: Outdoor, porch: Vector3, out: Vector3) -> Vector3:
	var at := level.world_to_cell(porch)
	var open: Array[Vector3] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := at + Vector2i(dx, dy)
			var p := level.cell_to_world(c)
			var to := p - porch
			to.y = 0.0
			if to.length() > STREET_REACH or to.dot(out) < -0.5 or not _clear(level, p, porch):
				continue
			open.append(p)
	if open.is_empty():
		return porch
	return open[_rng.randi() % open.size()]


## Whether the straight walk from `a` to `b` stays on open ground (the porch's own tile counts).
static func _clear(level: Outdoor, a: Vector3, b: Vector3) -> bool:
	var end := level.world_to_cell(b)
	var steps := maxi(1, int(a.distance_to(b) / 0.5))
	for i in steps + 1:
		var c := level.world_to_cell(a.lerp(b, float(i) / steps))
		if c != end and not level.is_open(c):
			return false
	return true


## Sends everyone who is free and has no seat yet to one; again and again while the gathering lasts,
## so someone who was busy (a chat, a rest on a bench) or still getting out of bed comes too.
func _dispatch(level: Outdoor) -> void:
	if speaker != null and is_instance_valid(speaker) and not speaker.serves() and speaker.can_attend():
		speaker.go_to_service(_trip(level, pulpit, true))
	for v: Villager in level.villagers:
		if v == speaker or not goes(v) or v.serves() or int(_tries.get(v, 0)) >= TRIES or not near(v):
			continue
		if v.rests():
			# Up from the fountain bench first (see BenchRest): they come on the next tick.
			v.leave_meal()
		if not v.can_attend():
			continue
		var seat := _free_seat()
		if seat.is_empty():
			return
		seat.taker = v
		_tries[v] = int(_tries.get(v, 0)) + 1
		v.go_to_service(_trip(level, seat, false))


## A seat nobody has, picked at random (standing room only when the pews are full), {} when there is none.
func _free_seat() -> Dictionary:
	var free := seats.filter(func(s: Dictionary) -> bool: return s.taker == null and not s.get("standing", false))
	if free.is_empty():
		# The pews are full: standing room behind them.
		free = seats.filter(func(s: Dictionary) -> bool: return s.taker == null)
	if free.is_empty():
		return {}
	return free[_rng.randi() % free.size()]


## A seat whose taker was called away on the way or is gone is free again.
func _free_lost_seats() -> void:
	for s: Dictionary in seats:
		var v = s.taker
		if v == null:
			continue
		if not is_instance_valid(v) or not v.serves() or not is_same(v.service_spot(), s):
			s.taker = null


## Whether the speech can begin: the priestess stands at her place, and the others are sat down (or
## it is late: whoever is still on the way takes their seat as the speech goes on).
func _ready(level: Outdoor) -> bool:
	if speaker == null or not is_instance_valid(speaker) or speaker.service_step() != "at" or float(speaker.service_trip.clock) < SETTLE:
		return false
	if level.hour < SPEECH_FROM:
		return false
	if level.hour >= SPEECH_AT:
		return true
	for s: Dictionary in seats:
		var v = s.taker
		if v != null and is_instance_valid(v) and v.service_step() != "seated":
			return false
	return true


## The speech: a line every LINE_TIME seconds, the arms raised to start and to end it, then two
## answers from the pews, one after the other, then everyone gets up.
func _speak(level: Outdoor, delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	var lines := _lines.size()
	if _spoken < lines:
		var gesture := _spoken == 0 or _spoken == lines - 1
		speaker.preach(Lang.t(_lines[_spoken]), LINE_TIME - 0.3, gesture)
		_spoken += 1
		_clock = LINE_TIME if _spoken < lines else LINE_TIME + AMEN_AFTER
	elif _spoken < lines + ANSWERED:
		_answer(_spoken - lines)
		_spoken += 1
		_clock = AMEN_GAP if _spoken < lines + ANSWERED else AMEN_TIME
	else:
		phase = "leave"
		_send_off(level, true)


## One of the villagers on the pews (the `nth` to answer) answers the priestess.
func _answer(nth: int) -> void:
	if nth == 0:
		_answers = ANSWERS.duplicate()
		_answers.shuffle()
	var seated := []
	for s: Dictionary in seats:
		var v = s.taker
		if v != null and is_instance_valid(v) and v.service_step() == "seated" and not v.is_talking():
			seated.append(v)
	if seated.is_empty():
		return
	(seated[_rng.randi() % seated.size()] as Villager).say(Lang.t(_answers[nth % _answers.size()]), Vector3.INF, AMEN_TIME)


## Everyone in the temple (or still on the way to it) is sent off. `orderly`: one by one in a line,
## those nearest the door first and a pause (EXIT_GAP) between two, so nobody piles up at the door or
## bumps into another; otherwise (an alarm, nightfall) all at once. Someone who has their time
## already keeps it, and anyone who comes in late is given the next one (see exit_slot).
func _send_off(level: Outdoor, orderly: bool) -> void:
	var inside_door: Vector3 = level.walk_in.door_points(rec)[1] if not rec.is_empty() else Vector3.ZERO
	var line: Array[Villager] = []
	for v: Villager in level.villagers:
		if not v.serves():
			continue
		if v.service_step() in ["", "going"]:
			# Still out in the street: too late, on with the day.
			v.cancel_service()
			continue
		if v == speaker:
			continue
		if not orderly:
			v.service_trip["leave_in"] = 0.0
		elif float(v.service_trip.leave_in) < 0.0:
			line.append(v)
	line.sort_custom(func(a: Villager, b: Villager) -> bool:
		return _flat(a.service_spot().get("sit", a.global_position), inside_door) < _flat(b.service_spot().get("sit", b.global_position), inside_door))
	for v: Villager in line:
		v.service_trip["leave_in"] = exit_slot()
	if speaker != null and is_instance_valid(speaker) and speaker.serves() and not speaker.service_trip.is_empty():
		if not orderly:
			speaker.service_trip["leave_in"] = 0.0
		elif float(speaker.service_trip.leave_in) < 0.0:
			# The priestess goes last, once everyone else has their time.
			speaker.service_trip["leave_in"] = exit_slot()


## The next free place in the line out of the temple: seconds from now (see EXIT_GAP).
func exit_slot() -> float:
	var at := maxf(0.3, _queue_clock)
	_queue_clock = at + EXIT_GAP
	return at


## Whether nobody is on the way to the temple, in it or on the way out of it any more.
func _nobody_in(level: Outdoor) -> bool:
	for v: Villager in level.villagers:
		if v.serves():
			return false
	return true


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- The walk of one villager (called by Villager) ----------------------------

## One physics tick of the "service" task.
static func step(v: Villager, delta: float) -> void:
	var trip := v.service_trip
	if trip.is_empty():
		v.end_service()
		return
	v.keep_task(10.0)
	trip.clock = float(trip.clock) + delta
	# Nobody stays on past the service: whoever comes late, or whom the gathering forgot (it is
	# over, or its hour is), is sent out or turned back at the door.
	var morning: TempleMorning = v.level.temple_morning
	var over: bool = morning.phase == "idle" or morning.phase == "leave" or v.level.hour >= END
	if over:
		if String(trip.step) == "going":
			v.end_service()
			return
		if float(trip.leave_in) < 0.0:
			trip.leave_in = morning.exit_slot()
	var walk_in: WalkIn = v.level.walk_in
	var spot: Dictionary = trip.spot
	match String(trip.step):
		"going":
			var first: Vector3 = (trip.in_way as Array)[0]
			if _flat(v.global_position, first) > NEAR_STREET:
				# The way over came to nothing (no path): given up, no cutting through a wall.
				v.end_service()
				return
			trip.way = (trip.in_way as Array).duplicate()
			trip.step = "in"
			trip.clock = 0.0
			VillagePosts._pass_through(v, true)
		"in":
			if VillagePosts._walk(v, trip, delta):
				trip.clock = 0.0
				VillagePosts._pass_through(v, false)
				trip.step = "at" if trip.speaker else ("seated" if spot.get("standing", false) else "sitting")
				if not trip.speaker and not spot.get("standing", false):
					v.sit_down()
		"sitting":
			var t := minf(1.0, float(trip.clock) / SIT_TIME)
			_place(v, walk_in, (spot.stand as Vector3).lerp(spot.sit, smoothstep(0.0, 1.0, t)))
			v.turn_toward(spot.front, delta)
			if t >= 1.0:
				trip.step = "seated"
				v.play("Sit_Chair_Idle", 0.2)
		"seated":
			v.turn_toward(spot.front, delta)
			v.play("Idle" if spot.get("standing", false) else "Sit_Chair_Idle")
			if float(trip.leave_in) >= 0.0:
				trip.leave_in = float(trip.leave_in) - delta
				if float(trip.leave_in) <= 0.0:
					if spot.get("standing", false):
						_go_out(v, trip)
						return
					trip.step = "rising"
					trip.clock = 0.0
					v.stand_up()
		"rising":
			var t := minf(1.0, float(trip.clock) / SIT_TIME)
			_place(v, walk_in, (spot.sit as Vector3).lerp(spot.stand, smoothstep(0.0, 1.0, t)))
			if t >= 1.0:
				_go_out(v, trip)
		"at":
			# The priestess before the altar, her face to the pews.
			v.turn_toward(spot.front, delta)
			trip.busy = float(trip.busy) - delta
			v.play(v.work_anim() if float(trip.busy) > 0.0 else "Idle")
			if float(trip.leave_in) >= 0.0:
				trip.leave_in = float(trip.leave_in) - delta
				if float(trip.leave_in) <= 0.0:
					_go_out(v, trip)
		"out":
			if VillagePosts._walk(v, trip, delta):
				v.end_service()


static func _go_out(v: Villager, trip: Dictionary) -> void:
	trip.way = (trip.out_way as Array).duplicate()
	trip.step = "out"
	trip.clock = 0.0
	VillagePosts._pass_through(v, true)


## Sets the villager at `at`, the feet on the floor.
static func _place(v: Villager, walk_in: WalkIn, at: Vector3) -> void:
	v.global_position = Vector3(at.x, walk_in.floor_at(at), at.z)


## Out on the porch at once (called away inside by a fright or the night): the way back is not
## walked, the villager is where the door lets out. A walk still on the street is just forgotten.
static func release(v: Villager) -> void:
	var trip := v.service_trip
	if trip.is_empty():
		return
	if String(trip.step) != "going":
		var points: Array[Vector3] = v.level.walk_in.door_points(trip.rec)
		v.global_position = points[0]
		v.reset_physics_interpolation()
	VillagePosts._pass_through(v, false)
	v.service_trip = {}


## The service is over for this one: back to their own layer and no trip.
static func finish(v: Villager) -> void:
	VillagePosts._pass_through(v, false)
	v.service_trip = {}

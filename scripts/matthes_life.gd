class_name MatthesLife
extends RefCounted
## What Matthes, the street sweeper (see StreetSweeper), does when there is nothing to sweep: he lends the
## farmers of the valley a hand on their fields in spring and summer, and all year round he looks for a
## girlfriend. Sweeping always comes first (leaves in autumn, snow in winter, see Villager._sweep_out); this
## runs only when he is free, so his marked routes and shifts stay as they are.
##
## Field work (spring and summer, in the working hours WORK_HOURS): he picks a farmer at work, walks to the
## field beside them and hoes (the hoe in his fist), weeds, or carries a sack of seed from a barn door to the
## field. The farmer greets him.
##
## Courtship (any season, a few visits a day, cooldown VISIT_GAP): he walks up to one of the village's
## women, lingers a little way off, shy, with his hat in the way of his eyes, then offers a wildflower of the
## season. A slow burn, by points of "fond" per woman (see `love`, saved with the game):
##   0       a shy hello, nothing in his hands; she answers kindly,
##   1 to 2  a flower; she says yes or politely no (the chance grows with every yes),
##   3 to 5  the same, and she is warmer (he is a regular now),
##   6+      sweethearts: he brings a flower every visit, they stand together and hearts rise. He no longer
##           looks at anyone else.
## A "no" costs him nothing but the day with her: he droops, a grey "...", and tries someone else next time.
## Everything is a task of its own, "tend" (see Villager._physics_process), driven by step() below.

const ROLE := StreetSweeper.ROLE
const TASK := "tend"
## The hours he helps on the fields (spring and summer), with a break at noon for his courting.
const WORK_HOURS := [[8.0, 11.5], [13.5, 17.0]]
## The hours he looks for company at all: not before the sweeping shift, not into the night.
const LOVE_HOURS := [8.0, 20.0]
## Game hours between two visits, and the most visits a day.
const VISIT_GAP := 1.4
const VISITS_PER_DAY := 3
## Points of "fond" at which things change (see above).
const FLOWER_FROM := 1
const SWEETHEARTS := 6
## How close he stands to her (metres), and how far away she may have wandered before he gives up.
const STAND_OFF := 1.9
const STAND_OFF_SHY := 2.5
const GIVE_UP_AT := 6.0

const WOMEN := {
	"2": {"warm": 0.5, "name": "Lene"},
	"ψ": {"warm": 0.4, "name": "Gerda"},
	"6": {"warm": 0.3, "name": "Mira"},
	"9": {"warm": 0.6, "name": "Hanna"},
	"µ": {"warm": 0.45, "name": "Ilse"},
}
## What they answer, by woman (a role letter): a shy hello, a yes, a no. Others fall back to the common lines.
const SHY := [
	"Ähm... guten Tag. Schönes Wetter, nicht wahr?",
	"Ich... kam zufällig vorbei. Mit dem Besen. Ja.",
	"Hallo! Ich wollte nur... hallo sagen.",
]
const HELLO := [
	"Guten Tag, Matthes! Fleißig wie immer.",
	"Ach, Matthes. Das ist nett, dass du vorbeischaust.",
]
const OFFER := [
	"Die habe ich am Wegrand gepflückt. Für dich.",
	"Die ist... für dich. Ist nichts Besonderes.",
	"Blumen halten länger als Laub. Hier, für dich.",
]
const YES := [
	"Oh, wie schön! Danke, Matthes.",
	"Die ist hübsch. Du bist ein Lieber.",
	"Eine Blume vom Straßenfeger! Die stelle ich ins Wasser.",
]
const NO := [
	"Das ist lieb gemeint, Matthes, aber ich... nein, danke.",
	"Ach Matthes. Heute nicht, ja?",
	"Du bist nett, aber mein Herz ist woanders.",
]
const SWEET := [
	"Matthes! Ich habe schon auf dich gewartet.",
	"Mit dir ist selbst ein Besen romantisch.",
	"Bleib noch einen Moment, ja?",
]
const SWEET_HIM := [
	"Ich glaube, ich bin der glücklichste Straßenfeger der Welt.",
	"Der Weg zu dir ist der einzige, den ich nie kehren muss.",
]
const SIGH := [
	"Na ja. Der Weg will auch gekehrt werden.",
	"Vielleicht beim nächsten Mal.",
	"Ich bin zu schüchtern. Oder zu staubig.",
]
const FIELD_HELLO := [
	"Matthes, du packst mit an? Das ist nett!",
	"Eine Hand mehr schadet nie. Danke, Matthes!",
	"Der Straßenfeger hilft auf dem Feld. Dann wird es heute früh fertig.",
]
const FIELD_SAY := {
	"hoe": ["Ich hacke die Furchen locker. Das ist wie Kehren, nur im Boden."],
	"weed": ["Unkraut zupfen: wie Laub kehren, aber das Laub wehrt sich."],
	"sack": ["Ein Sack Saatgut für die Bauern. Schwer, aber ehrlich."],
}
## What he says to the hero (see Villager.talk), by how far things have got: the lines come after his usual ones.
const TALK_SHY := ["Frag nicht nach dem Mädchen. Ich werde rot.", "Hast du eine Blume? Ich brauche nur eine."]
const TALK_SWEET := ["Wir gehen zusammen spazieren. Fast jeden Tag!", "Sie sagt, ich rieche nach Birke. Ich glaube, das war ein Kompliment."]

## What he carries and holds, hung in his right hand (see props()).
const HOE := "MatthesHoe"
const SACK := "MatthesSack"
const FLOWER := "MatthesFlower"

## Saved with the game: {role: points of fondness}. The days she turned him down are not kept.
static var love := {}
## Not saved: the day of a "no", per woman, and the day's visits.
static var _snubbed := {}
static var _visits := {"day": -1, "n": 0, "next": 0.0}
static var _hearts: Dictionary = {}
static var _heart_texture: ImageTexture


static func for_save() -> Dictionary:
	return love.duplicate()


static func load_from(saved) -> void:
	clear()
	if saved is Dictionary:
		for role: String in saved:
			if WOMEN.has(role):
				love[role] = clampi(int(saved[role]), 0, 99)


static func clear() -> void:
	love = {}
	_snubbed = {}
	_visits = {"day": -1, "n": 0, "next": 0.0}


## How far things have got with a woman (a role letter): 0 a stranger up to SWEETHEARTS and beyond.
static func fond(role: String) -> int:
	return int(love.get(role, 0))


## The woman he is sweet on (fond at SWEETHEARTS or more), or "" while he is still looking.
static func sweetheart() -> String:
	for role: String in WOMEN:
		if fond(role) >= SWEETHEARTS:
			return role
	return ""


# --- Choosing what to do ---------------------------------------------------------------------

static func _in(hour: float, spans: Array) -> bool:
	return spans.any(func(s: Array) -> bool: return hour >= float(s[0]) and hour < float(s[1]))


## Whether the fields want him: spring or summer, working hours, no rain.
static func field_time(level: Outdoor) -> bool:
	var season := Weather.season(level.season_day)
	return (season == "spring" or season == "summer") and _in(level.hour, WORK_HOURS) \
			and level.weather != Weather.RAIN and level.weather != Weather.STORM


## Called when he has nothing to sweep (see Villager._next_task): sets him on field work or off to court
## someone. True when he goes.
static func next(v: Villager) -> bool:
	var level := v.level as Outdoor
	if level == null or v.night or v.at_home or not v.visible or v.threat != null or level.village_alarm.raised:
		return false
	if level.hour < LOVE_HOURS[0] or level.hour >= LOVE_HOURS[1]:
		return false
	if field_time(level):
		return _start_field_job(v, level)
	return _start_visit(v, level)


# --- Field work --------------------------------------------------------------------------------

## The farmers of the valley who are at work on a field right now.
static func _working_farmers(level: Outdoor) -> Array:
	var out: Array = []
	for o: Villager in level.villagers:
		if ValleyFolk.FARMERS.contains(o.role) and o.visible and not o.at_home and o._task == "work" and o._job.has("face"):
			# Only those on a field (a farmer at the well or a door is not).
			if CropFields.LETTERS.contains(level.cell_char(level.world_to_cell(o._job.face))):
				out.append(o)
	return out


static func _start_field_job(v: Villager, level: Outdoor) -> bool:
	var s := _state(v)
	var season := Weather.season(level.season_day)
	var kinds: Array = ["hoe", "sack"] if season == "spring" else ["hoe", "weed", "sack"]
	kinds.erase(s.get("last", ""))
	var kind: String = kinds[v._rng.randi() % kinds.size()]
	var farmers := _working_farmers(level)
	var farmer: Villager = null
	if not farmers.is_empty():
		farmer = farmers[v._rng.randi() % farmers.size()]
	var spot := Vector3.INF
	var face := Vector3.INF
	var letter := ""
	if farmer != null:
		letter = level.cell_char(level.world_to_cell(farmer._job.face))
		var best := 1e9
		for e: Dictionary in ValleyFolk.edge_spots(level, letter):
			var d: float = e.spot.distance_to(farmer.global_position)
			# Beside the farmer, not on top of them.
			if d >= 2.2 and d < best and not _crowded(level, e.spot):
				best = d
				spot = e.spot
				face = e.face
	if spot == Vector3.INF:
		var place := ValleyFolk._place(level, v, {"where": CropFields.WHEAT if v._rng.randf() < 0.5 else CropFields.MAIZE})
		if place.is_empty():
			return false
		spot = place.spot
		face = place.face
	var plan := {"kind": kind, "phase": "walk", "face": face, "spot": spot, "t": 0.0, "farmer": farmer}
	if kind == "sack":
		var doors := ValleyFolk.door_spots(level)
		if doors.is_empty():
			plan.kind = "hoe"
		else:
			plan.door = doors[v._rng.randi() % doors.size()].spot
			plan.phase = "fetch"
	v.set_meta("tend", plan)
	s.last = plan.kind
	v._walk_to(plan.door if plan.has("door") else spot, Villager.WALK_SPEED, TASK)
	return true


static func _crowded(level: Outdoor, at: Vector3) -> bool:
	for o: Villager in level.villagers:
		if o.visible and not o.at_home and o.global_position.distance_to(at) < 1.6:
			return true
	return false


# --- Courtship ---------------------------------------------------------------------------------

## Who he would court now: a woman out in the open and free to talk, the one he is sweet on first, else
## one who did not turn him down today, the most fond of him first.
static func _suitor(v: Villager, level: Outdoor) -> Villager:
	var today := level.season_day
	var best: Villager = null
	var best_score := -1.0
	var sweet := sweetheart()
	for o: Villager in level.villagers:
		if not WOMEN.has(o.role) or not _free(o):
			continue
		if sweet != "" and o.role != sweet:
			continue
		if _snubbed.get(o.role, -1) == today:
			continue
		var d := o.global_position.distance_to(v.global_position)
		if d > 90.0:
			continue
		var score := float(fond(o.role)) * 10.0 + v._rng.randf() * 6.0 - d * 0.05
		if score > best_score:
			best_score = score
			best = o
	return best


## Whether a woman can be talked to: out and about, on her feet, not behind a counter or in a chat.
static func _free(o: Villager, mid_visit := false) -> bool:
	if o.at_home or not o.visible or o.night or o.threat != null or o.is_asleep() or o.eaten:
		return false
	if o._task in ["post", "home", "service", "dine", "frozen", "fight", "hide", "defend", "climb", "bless", "mend"]:
		return false
	return o.chat_partner == null and (mid_visit or o._bubble_time <= 0.0)


static func _start_visit(v: Villager, level: Outdoor) -> bool:
	var today := level.season_day
	if int(_visits.day) != today:
		_visits = {"day": today, "n": 0, "next": 0.0}
	if int(_visits.n) >= VISITS_PER_DAY or level.world_hours < float(_visits.next):
		return false
	var her := _suitor(v, level)
	if her == null:
		return false
	_visits.n = int(_visits.n) + 1
	_visits.next = level.world_hours + VISIT_GAP
	var f := fond(her.role)
	var plan := {"kind": "visit", "phase": "walk", "her": her, "t": 0.0, "tries": 0, "fond": f}
	v.set_meta("tend", plan)
	v._walk_to(her.global_position, Villager.WALK_SPEED, TASK)
	return true


## Where he stands to talk to her: STAND_OFF from her, on the side he comes from, on open ground.
static func _stand_by(v: Villager, her: Villager, gap: float) -> Vector3:
	var level := v.level as Outdoor
	var from := v.global_position - her.global_position
	from.y = 0.0
	var dir := from.normalized() if from.length() > 0.1 else Vector3.BACK
	for k in 8:
		var turned := dir.rotated(Vector3.UP, k * 0.5 * (1.0 if k % 2 == 0 else -1.0))
		var at := her.global_position + turned * gap
		at.y = v.global_position.y
		if level.is_open(level.world_to_cell(at)) and not v.blocked_at(at):
			return at
	return v.global_position


# --- Every tick ---------------------------------------------------------------------------------

static func _state(v: Villager) -> Dictionary:
	if not v.has_meta("tend_state"):
		v.set_meta("tend_state", {})
	return v.get_meta("tend_state")


## Whether a job is going on (the task "tend" with its plan).
static func busy(v: Villager) -> bool:
	return v.has_meta("tend") and not (v.get_meta("tend") as Dictionary).is_empty()


## One physics tick of the task "tend" (called by Villager._physics_process).
static func step(v: Villager, delta: float) -> void:
	var plan: Dictionary = v.get_meta("tend", {})
	if plan.is_empty():
		v._start("idle", 0.5)
		return
	if plan.kind == "visit":
		_visit_step(v, plan, delta)
	else:
		_field_step(v, plan, delta)


## Called whenever any other task begins (see Villager._start): puts the tools down and stands up straight.
static func stop(v: Villager) -> void:
	if v.has_meta("tend"):
		v.remove_meta("tend")
	show_prop(v, "", false)
	v._model.rotation.x = 0.0
	v._model.rotation.z = 0.0
	v._job = {}


## Ends the job: he stands a breath, then the day goes on (see Villager._next_task).
static func finish(v: Villager, rest := 2.0) -> void:
	v._start("idle", rest + v._rng.randf() * 2.0)


static func _field_step(v: Villager, plan: Dictionary, delta: float) -> void:
	var level := v.level as Outdoor
	plan.t = float(plan.t) - delta
	match String(plan.phase):
		"fetch":
			# At the barn door: shoulder a sack, then on to the field.
			plan.phase = "lift"
			plan.t = 1.6
			v._job = {"anim": "PickUp", "face": v.global_position + Vector3(0, 0, -2)}
		"lift":
			v._do("work", delta)
			if float(plan.t) <= 0.0:
				show_prop(v, SACK, true)
				plan.phase = "walk"
				v._walk_to(plan.spot, Villager.WALK_SPEED * 0.9, TASK)
		"walk":
			# Arrived at the field's edge.
			plan.phase = "work"
			plan.t = v._rng.randf_range(12.0, 22.0) if plan.kind != "sack" else 2.2
			if plan.kind == "hoe":
				show_prop(v, HOE, true)
			v._job = {"anim": "PickUp" if plan.kind != "hoe" else "2H_Melee_Attack_Chop", "face": plan.face}
			if plan.kind == "sack":
				show_prop(v, SACK, false)
			_greet(v, plan)
		"work":
			if plan.kind == "weed" or plan.kind == "hoe":
				v._do("work", delta)
			else:
				v._do("work", delta)
			if float(plan.t) <= 0.0 or not field_time(level):
				finish(v, 1.5)


## The farmer he helps looks up and says a word, and he says one back, once per job.
static func _greet(v: Villager, plan: Dictionary) -> void:
	var farmer: Villager = plan.get("farmer")
	var level := v.level as Outdoor
	if level.player == null or level.player.global_position.distance_to(v.global_position) > ValleyFolk.SAY_RANGE:
		return
	if farmer != null and is_instance_valid(farmer) and farmer.global_position.distance_to(v.global_position) < 8.0 and v._rng.randf() < 0.7:
		Effects.head_text(level, farmer, 2.6 * float(farmer._info.get("scale", 1.0)), Lang.t(FIELD_HELLO[v._rng.randi() % FIELD_HELLO.size()]), Color(0.96, 0.9, 0.7))
	elif FIELD_SAY.has(plan.kind) and v._rng.randf() < 0.5:
		Effects.head_text(level, v, 2.6, Lang.t(FIELD_SAY[plan.kind][0]), Color(0.96, 0.9, 0.7))


static func _visit_step(v: Villager, plan: Dictionary, delta: float) -> void:
	var her: Villager = plan.get("her")
	var level := v.level as Outdoor
	if her == null or not is_instance_valid(her) or not _free(her, true):
		_give_up(v, plan, false)
		return
	plan.t = float(plan.t) - delta
	var f := int(plan.fond)
	var to_her := her.global_position - v.global_position
	to_her.y = 0.0
	match String(plan.phase):
		"walk":
			# Walked up to where she was: close the last stretch by hand, to a talking distance.
			if to_her.length() > GIVE_UP_AT:
				plan.tries = int(plan.tries) + 1
				if int(plan.tries) > 2:
					_give_up(v, plan, false)
				else:
					v._walk_to(her.global_position, Villager.WALK_SPEED, TASK)
				return
			plan.phase = "close"
			plan.goal = _stand_by(v, her, STAND_OFF_SHY if f < FLOWER_FROM else STAND_OFF)
		"close":
			var goal: Vector3 = plan.goal
			var left := goal - v.global_position
			left.y = 0.0
			if left.length() < 0.1 or float(plan.t) < -6.0:
				plan.phase = "shy"
				plan.t = 2.6
				_pause(her, 9.0)
				if f >= SWEETHEARTS:
					v.say(Lang.t(SWEET_HIM[v._rng.randi() % SWEET_HIM.size()]), her.global_position, 3.2)
				else:
					v.say(Lang.t(SHY[v._rng.randi() % SHY.size()]), her.global_position, 3.2)
				return
			# A slow, careful walk up to her.
			var walked := v._stride("Walking_B", 0.9)
			var step := minf(walked * delta, left.length())
			var next := v.global_position + left.normalized() * step
			if not v.blocked_at(next):
				v.global_position = next
			v._turn_to(to_her, delta)
			_keep(her, v, delta)
		"shy":
			v._turn_to(to_her, delta)
			_keep(her, v, delta)
			_shy_pose(v, float(plan.t))
			if float(plan.t) <= 0.0:
				if f < FLOWER_FROM:
					# Just a hello: she answers, and he is glad of it.
					plan.phase = "after"
					plan.t = 2.4
					plan.yes = true
					her.say(Lang.t(HELLO[v._rng.randi() % HELLO.size()]), v.global_position, 3.0)
					_raise(v, 1)
					v.play("Cheer")
					return
				if f >= SWEETHEARTS:
					plan.phase = "date"
					plan.t = 11.0
					show_prop(v, FLOWER, true)
					her.say(Lang.t(SWEET[v._rng.randi() % SWEET.size()]), v.global_position, 3.4)
					_hearts_at(level, (v.global_position + her.global_position) * 0.5 + Vector3(0, 2.2, 0))
					return
				plan.phase = "offer"
				plan.t = 2.6
				show_prop(v, FLOWER, true)
				v.say(Lang.t(OFFER[v._rng.randi() % OFFER.size()]), her.global_position, 3.0)
				v.play("Interact")
		"offer":
			v._turn_to(to_her, delta)
			_keep(her, v, delta)
			if float(plan.t) <= 0.0:
				var chance := clampf(float(WOMEN[her.role].warm) + 0.07 * f, 0.15, 0.92)
				plan.yes = v._rng.randf() < chance
				plan.phase = "after"
				plan.t = 3.0
				show_prop(v, FLOWER, false)
				if plan.yes:
					her.say(Lang.t(YES[v._rng.randi() % YES.size()]), v.global_position, 3.2)
					_hearts_at(level, (v.global_position + her.global_position) * 0.5 + Vector3(0, 2.3, 0))
					_raise(v, 1)
					v.play("Cheer")
				else:
					her.say(Lang.t(NO[v._rng.randi() % NO.size()]), v.global_position, 3.2)
					_snubbed[her.role] = level.season_day
					Effects.head_text(level, v, 2.5, "...", Color(0.7, 0.72, 0.78))
					v.play("Idle")
		"date":
			v._turn_to(to_her, delta)
			_keep(her, v, delta)
			_shy_pose(v, 0.0)
			if fmod(float(plan.t), 4.0) < delta and float(plan.t) > 1.0:
				_hearts_at(level, (v.global_position + her.global_position) * 0.5 + Vector3(0, 2.2, 0))
			if float(plan.t) <= 0.0:
				plan.phase = "after"
				plan.t = 2.0
				plan.yes = true
				show_prop(v, FLOWER, false)
				_raise(v, 0)
				v.play("Cheer")
		"after":
			if plan.yes:
				v._turn_to(to_her, delta)
				_keep(her, v, delta)
			else:
				# Droops: head down, shoulders forward, and a sigh.
				v._model.rotation.x = lerpf(v._model.rotation.x, 0.22, minf(1.0, delta * 3.0))
				if float(plan.t) > 2.4 and float(plan.t) - delta <= 2.4:
					v.say(Lang.t(SIGH[v._rng.randi() % SIGH.size()]), Vector3.INF, 3.0)
			if float(plan.t) <= 0.0:
				finish(v, 1.0)


## A woman stays for the scene: held in her place, turned to him, until it is over.
static func _pause(her: Villager, time: float) -> void:
	if her._task != "idle":
		her._start("idle", time)
	her._task_time = maxf(her._task_time, time)


static func _keep(her: Villager, v: Villager, delta: float) -> void:
	if her._task == "idle":
		her._task_time = maxf(her._task_time, 1.2)
		her.turn_toward(v.global_position - her.global_position, delta)


## Shy: his weight shifts from foot to foot, the head drops a little and he turns the hat in his hand.
static func _shy_pose(v: Villager, t: float) -> void:
	var sway := sin(Time.get_ticks_msec() * 0.004) * 0.05
	v._model.rotation.z = sway
	v._model.rotation.x = 0.09
	v.play("Idle")


static func _give_up(v: Villager, plan: Dictionary, snub: bool) -> void:
	finish(v, 1.0)


## A point of fondness (none for `by` 0). Hearts rise.
static func _raise(v: Villager, by: int) -> void:
	var plan: Dictionary = v.get_meta("tend", {})
	var her: Villager = plan.get("her")
	if her == null or by == 0:
		return
	var f := fond(her.role)
	love[her.role] = f + by
	if f < SWEETHEARTS and f + by >= SWEETHEARTS:
		Events.tell(Lang.t("Matthes und %s sind jetzt ein Paar.") % WOMEN[her.role].name, Color(1.0, 0.7, 0.8))


## The extra lines he tells the hero, by how his courting stands.
static func talk_lines(lines: Array) -> Array:
	return lines + (TALK_SWEET if sweetheart() != "" else TALK_SHY)


# --- Props ---------------------------------------------------------------------------------------

## Shows one of the props in his hand (HOE, SACK, FLOWER) and hides the others; "" hides all.
static func show_prop(v: Villager, which: String, on: bool) -> void:
	if v._model == null:
		return
	var hand := v._model.find_child("handslot_r", true, false)
	if hand == null:
		return
	for name: String in [HOE, SACK, FLOWER]:
		var prop := hand.get_node_or_null(name) as Node3D
		if on and name == which:
			if prop == null:
				prop = _make(name, hand, v)
			prop.visible = true
		elif prop != null and (on or which == ""):
			prop.visible = false
	if on and which == FLOWER:
		var prop := hand.get_node_or_null(FLOWER) as MeshInstance3D
		if prop != null:
			prop.mesh = flower_mesh(Weather.season((v.level as Outdoor).season_day))


static func _make(name: String, hand: Node3D, v: Villager) -> Node3D:
	var prop: MeshInstance3D
	match name:
		HOE:
			prop = hoe(hand)
		SACK:
			prop = sack(hand)
		_:
			prop = flower(hand, Weather.season((v.level as Outdoor).season_day))
	prop.name = name
	return prop


const ASH := Color(0.62, 0.48, 0.32)
const IRON := Color(0.5, 0.5, 0.54)
const BURLAP := Color(0.72, 0.6, 0.38)
const STEM := Color(0.32, 0.55, 0.22)


## A hoe: an ash handle along +y with an iron blade at the top turned down and out.
static func hoe(parent: Node3D) -> MeshInstance3D:
	var b := WeatheredProps.Builder.new()
	b.bar(Vector3(0, -0.3, 0), Vector3(0, 1.15, 0), 0.024, ASH, WeatheredProps.WOOD, 7)
	b.cylinder(Vector3(0, 1.1, 0), 0.032, 0.03, 0.06, IRON * 0.8, WeatheredProps.IRON, 7)
	b.bar(Vector3(0, 1.14, 0), Vector3(-0.1, 1.2, 0), 0.016, IRON, WeatheredProps.IRON, 5)
	b.box(Vector3(-0.17, 1.02, 0), Vector3(0.16, 0.2, 0.028), IRON, WeatheredProps.IRON, Basis(Vector3.BACK, 0.12))
	return b.finish(parent, Vector3.ZERO, true, true)


## A sack of seed: a plump burlap bag, its neck tied with twine, a seam down the side.
static func sack(parent: Node3D) -> MeshInstance3D:
	var b := WeatheredProps.Builder.new()
	b.cylinder(Vector3(0.0, -0.2, 0.0), 0.2, 0.17, 0.4, BURLAP, WeatheredProps.FRESH, 12)
	b.cylinder(Vector3(0.0, -0.2, 0.0), 0.17, 0.2, 0.08, BURLAP * 0.9, WeatheredProps.FRESH, 12)
	b.cylinder(Vector3(0.0, 0.2, 0.0), 0.17, 0.06, 0.12, BURLAP, WeatheredProps.FRESH, 10)
	b.cylinder(Vector3(0.0, 0.2, 0.0), 0.075, 0.075, 0.025, Color(0.35, 0.24, 0.14), WeatheredProps.FRESH, 8)
	b.box(Vector3(0.0, -0.14, 0.18), Vector3(0.025, 0.32, 0.02), BURLAP * 0.7, WeatheredProps.FRESH)
	return b.finish(parent, Vector3(0, 0.05, 0.15), true, true)


const PETALS := {
	"spring": Color(0.95, 0.62, 0.78), "summer": Color(0.9, 0.2, 0.18),
	"autumn": Color(0.95, 0.55, 0.16), "winter": Color(0.96, 0.97, 1.0),
}


static func flower(parent: Node3D, season: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = flower_mesh(season)
	mi.material_override = WeatheredProps.vertex_material(true)
	parent.add_child(mi)
	return mi


## A wildflower held by its stem: two leaves, a ring of petals round a yellow heart.
static func flower_mesh(season: String) -> ArrayMesh:
	var b := WeatheredProps.Builder.new()
	var petal: Color = PETALS.get(season, PETALS.summer)
	b.bar(Vector3(0, -0.1, 0), Vector3(0, 0.34, 0), 0.01, STEM, WeatheredProps.FRESH, 5)
	for s in [-1.0, 1.0]:
		b.bar(Vector3(0, 0.08, 0), Vector3(0.07 * s, 0.17, 0.0), 0.008, STEM * 1.1, WeatheredProps.FRESH, 4)
	var n := 6
	for k in n:
		var a := TAU * k / n
		var out := Vector3(cos(a), 0, sin(a))
		b.bar(Vector3(0, 0.36, 0) + out * 0.015, Vector3(0, 0.37, 0) + out * 0.075, 0.017, petal * (0.9 if k % 2 == 0 else 1.0), WeatheredProps.FRESH, 5)
	b.cylinder(Vector3(0, 0.355, 0), 0.026, 0.02, 0.025, Color(0.98, 0.82, 0.2), WeatheredProps.FRESH, 8)
	var holder := Node3D.new()
	var mi := b.finish(holder)
	var mesh := mi.mesh as ArrayMesh
	holder.free()
	return mesh


# --- Hearts --------------------------------------------------------------------------------------

## Small hearts rising from `at` (a one-shot spray; the emitter is kept on the level).
static func _hearts_at(level: Outdoor, at: Vector3) -> void:
	var emitter := _hearts.get(level.get_instance_id()) as CPUParticles3D
	if emitter == null or not is_instance_valid(emitter):
		emitter = CPUParticles3D.new()
		emitter.name = "Hearts"
		emitter.one_shot = true
		emitter.emitting = false
		emitter.explosiveness = 0.9
		emitter.amount = 7
		emitter.lifetime = 2.4
		emitter.direction = Vector3.UP
		emitter.spread = 25.0
		emitter.gravity = Vector3.ZERO
		emitter.initial_velocity_min = 0.5
		emitter.initial_velocity_max = 0.9
		emitter.scale_amount_min = 0.7
		emitter.scale_amount_max = 1.2
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		emitter.color_ramp = fade
		var quad := QuadMesh.new()
		quad.size = Vector2(0.4, 0.4)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = heart_texture()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = mat
		emitter.mesh = quad
		emitter.local_coords = false
		emitter.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		level.add_child(emitter)
		_hearts[level.get_instance_id()] = emitter
	emitter.global_position = at
	emitter.restart()
	emitter.emitting = true


## A soft red heart with a lighter highlight, 32 pixels, round edges.
static func heart_texture() -> ImageTexture:
	if _heart_texture != null:
		return _heart_texture
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var px := (x + 0.5) / size * 2.4 - 1.2
			var py := 1.15 - (y + 0.5) / size * 2.4
			# The heart curve: (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0.
			var v := pow(px * px + py * py - 1.0, 3.0) - px * px * pow(py, 3.0)
			if v <= 0.0:
				var depth := clampf(-v * 6.0, 0.0, 1.0)
				var col := Color(0.82, 0.12, 0.22).lerp(Color(1.0, 0.45, 0.55), depth * 0.6)
				var shine := clampf(1.0 - Vector2(px + 0.45, py - 0.4).length() * 2.5, 0.0, 1.0)
				col = col.lerp(Color(1, 0.85, 0.88), shine * 0.7)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	img.generate_mipmaps()
	_heart_texture = ImageTexture.create_from_image(img)
	return _heart_texture

class_name WarHorn
extends RefCounted
## The village's alarm horn: a great Norse horn on a timber cradle just inside
## the west gate, beside the guard's post (see VillageProps.build_war_horn).
## When the village is alarmed (see VillageBell, Events.alarm) the town guard
## runs to the horn's mouthpiece and blows it, two long, deep blasts like a big
## ship's fog horn with a breath between them (HornBlow: each blast sounds
## while the blower's lips are on the horn, tools/make_horn_sounds.py). The
## church bell then tolls after the horn has died away, so the two never sound
## over each other; the bell's cooldown (VillageBell.COOLDOWN) covers both.
## With no guard to blow it (away, hurt, eaten, in his house) the bell tolls
## alone. The hero can blow it too, the same way.

const SOUND := "war_horn"
## The station kind of the horn the hero can blow.
const KIND := "kriegshorn"
## Seconds before the hero may blow the horn again.
const HERO_COOLDOWN := 60.0
const BLOWN := "Du stößt ins Horn. Das Dorf versammelt sich auf dem Marktplatz."
const BLOWN_ALONE := "Du stößt ins Horn. Niemand scheint es zu hören."
const TOO_SOON := "Das Horn braucht noch einen Moment, bis es wieder erschallt."
const BUSY := "Die Wache bläst gerade schon ins Horn."
const BUSY_HERO := "Du bläst doch schon ins Horn."
## The loudness of the horn, in dB (it carries over the whole village).
const VOLUME_DB := 2.0
## The quiet after the horn before the bell follows (seconds).
const GAP := 0.4
## How far from the horn the guard can still be and run to it (metres).
const REACH := 30.0
## Seconds after which the bell tolls alone if the guard never reaches the horn.
const TIMEOUT := 25.0

static var _sounded := true
## The hero's blowing of the horn, while it lasts (see hero_blow).
static var _hero_blow: HornBlow


## Where the horn stands: inside the wall, on the free tile beside the guard's
## post at the west gate (so he can reach it at once), off to the side of the
## gateway so it never blocks the way in. Vector3.INF where there is no wall.
static func spot(o: Outdoor) -> Vector3:
	var gate := GuardWatch.west_gate(o)
	if gate == null:
		return Vector3.INF
	var post := GuardWatch.post(o)
	var inward := (post - gate.global_position).normalized()
	var around := o.world_to_cell(post)
	var best := Vector3.INF
	var best_score := INF
	for d in Level.DIRS:
		var c: Vector2i = around + d
		if not o.is_open(c) or o.village_wall.bricks.has(c):
			continue
		var p := o.cell_to_world(c)
		# Beside the gateway (across the way in), not in front of it.
		var score := absf(Vector3(d.x, 0, d.y).dot(inward))
		if score < best_score:
			best_score = score
			best = p
	return best


## The way the horn faces (the yaw of VillageProps.build_war_horn): its bell
## points at the gate, out to where the slimes come from.
static func facing(o: Outdoor, at: Vector3) -> float:
	var gate := GuardWatch.west_gate(o)
	if gate == null:
		return 0.0
	var d := gate.global_position - at
	return atan2(d.z, -d.x)


## The guard, if he can run to the horn and blow it now; else null.
static func guard(o: Outdoor) -> Villager:
	if o.war_horn_at == Vector3.INF:
		return null
	if hero_blowing():
		return null
	for v in o.villagers:
		if v.role == "4" and v.can_blow_horn(o.war_horn_at):
			return v
	return null


## The guard runs to the horn and blows it (see Villager.sound_alarm, which
## calls `sound` once he sets out from his post to the mouthpiece). Returns whether he is on it: false when
## nobody can blow it and the bell has to toll alone.
static func blow(o: Outdoor) -> bool:
	var v := guard(o)
	if v == null:
		return false
	_sounded = false
	v.sound_alarm(o.war_horn_at)
	# Should he never get to it (he is cut down, called to the wall), the bell tolls anyway.
	o.get_tree().create_timer(TIMEOUT).timeout.connect(func():
		if is_instance_valid(o) and o.is_inside_tree() and not _sounded:
			_sounded = true
			Sfx.play(o, VillageBell.SOUND, VillageBell.VOLUME_DB))
	return true


## The guard sets his lips to the horn: it will sound for `seconds` (see
## HornBlow.seconds_left, the blasts themselves sound as he blows them), and
## the bell tolls after it, even should he be called away half way.
static func sound(o: Outdoor, seconds: float) -> void:
	if _sounded:
		return
	_sounded = true
	Sfx.play_after(o, seconds + GAP, VillageBell.SOUND, VillageBell.VOLUME_DB)


static var _hero_last := -INF


## Forgets when the hero last blew the horn (a new game, a test).
static func reset_hero() -> void:
	_hero_last = -INF
	_hero_blow = null


## Whether the hero is at the horn blowing it now.
static func hero_blowing() -> bool:
	return _hero_blow != null and not _hero_blow.done


## Why the hero cannot blow the horn now (the text to show), or "" when they can.
static func hero_cannot(now := Time.get_ticks_msec() / 1000.0) -> String:
	if not _sounded:
		return Lang.t(BUSY)
	if hero_blowing():
		return Lang.t(BUSY_HERO)
	if now - _hero_last < HERO_COOLDOWN:
		return Lang.t(TOO_SOON)
	return ""


## The hero walks to the horn and blows it (see HornBlow; the hero's body plays
## it, Player.blow_horn). At the first blast the villagers gather on the square
## and `told` gets the text to show the hero. Should the hero walk off before
## the horn has sounded, it is as if they never tried: no cooldown.
static func hero_blow(o: Outdoor, from: Vector3, told := Callable(), now := Time.get_ticks_msec() / 1000.0) -> HornBlow:
	_hero_last = now
	var blow := HornBlow.begin(o, from)
	blow.on_blast = func(i: int):
		if i == 0:
			var text := Lang.t(BLOWN) if o.gather_village() else Lang.t(BLOWN_ALONE)
			if told.is_valid():
				told.call(text)
	blow.on_stop = func(sounded: int):
		if sounded == 0 and _hero_last == now:
			_hero_last = -INF
	_hero_blow = blow
	return blow

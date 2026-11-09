class_name WarHorn
extends RefCounted
## The village's alarm horn: a great Norse horn on a timber cradle just inside
## the west gate, beside the guard's post (see VillageProps.build_war_horn).
## When the village is alarmed (see VillageBell, Events.alarm) the town guard
## walks to the horn and blows it from there, two long, deep blasts like a big ship's fog horn
## (tools/make_horn_sounds.py). The church bell then tolls after the horn has
## died away, so the two never sound over each other; the bell's cooldown
## (VillageBell.COOLDOWN) covers both. With no guard to blow it (away, hurt,
## eaten, in his house) the bell tolls alone.

const SOUND := "war_horn"
## The loudness of the horn, in dB (it carries over the whole village).
const VOLUME_DB := 2.0
## How long the horn sounds (seconds), and the quiet before the bell follows.
const LENGTH := 6.5
const GAP := 0.4
## How far from the horn the guard can still be and run to it (metres).
const REACH := 30.0
## Seconds after which the bell tolls alone if the guard never reaches the horn.
const TIMEOUT := 25.0

static var _sounded := true


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
	for v in o.villagers:
		if v.role == "4" and v.can_blow_horn(o.war_horn_at):
			return v
	return null


## The guard walks to the horn and blows it (see Villager.sound_alarm, which
## calls `sound` once he stands at it). Returns whether he is on it: false when
## nobody can blow it and the bell has to toll alone.
static func blow(o: Outdoor) -> bool:
	var v := guard(o)
	if v == null:
		return false
	_sounded = false
	v.sound_alarm(o.war_horn_at)
	# Should he never get there (he is cut down, called to the wall), the bell tolls anyway.
	o.get_tree().create_timer(TIMEOUT).timeout.connect(func():
		if is_instance_valid(o) and o.is_inside_tree() and not _sounded:
			_sounded = true
			Sfx.play(o, VillageBell.SOUND, VillageBell.VOLUME_DB))
	return true


## The horn sounds, blown by the guard at the horn; the bell tolls after it.
static func sound(o: Outdoor) -> void:
	if _sounded:
		return
	_sounded = true
	Sfx.play(o, SOUND, VOLUME_DB, o.war_horn_at)
	Sfx.play_after(o, LENGTH + GAP, VillageBell.SOUND, VillageBell.VOLUME_DB)

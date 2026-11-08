class_name WarHorn
extends RefCounted
## The village's alarm horn: a great Norse horn on a timber cradle just inside
## the west gate (see VillageProps.build_war_horn). When the village is
## alarmed (see VillageBell, Events.alarm) the town guard runs to it and
## blows it, two long, deep blasts like a big ship's fog horn
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
## How far from the gate the horn stands (in tiles), at least and at most.
const GATE_MIN := 1.9
const GATE_MAX := 3.6


## Where the horn stands: a free spot inside the wall a few steps from the west
## gate, near the guard's post; Vector3.INF where the village has no wall.
static func spot(o: Outdoor) -> Vector3:
	var gate := GuardWatch.west_gate(o)
	if gate == null:
		return Vector3.INF
	var post := GuardWatch.post(o)
	var best := Vector3.INF
	var best_d := INF
	var around := o.world_to_cell(post)
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := around + Vector2i(dx, dy)
			if not o.is_open(c) or o.village_wall.bricks.has(c):
				continue
			var p := o.cell_to_world(c)
			var d := p.distance_to(gate.global_position)
			if d < GATE_MIN * Level.TILE or d > GATE_MAX * Level.TILE or p.distance_to(post) < Level.TILE * 0.9:
				continue
			if d < best_d:
				best_d = d
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


## The guard blows the horn. Returns how long to wait before the bell may toll
## (0 when nobody blew the horn).
static func blow(o: Outdoor) -> float:
	var v := guard(o)
	if v == null:
		return 0.0
	v.sound_alarm(o.war_horn_at, LENGTH)
	Sfx.play(o, SOUND, VOLUME_DB, o.war_horn_at)
	return LENGTH + GAP

class_name HornBlow
extends RefCounted
## Blowing the village's alarm horn (see WarHorn), for whoever blows it: the
## hero or the town guard. The blower walks round to the mouthpiece, fills
## their lungs, leans in and blows for as long as the first blast sounds,
## steps back from the mouthpiece and catches their breath, then leans in and
## blows the second blast. The sound (tools/make_horn_sounds.py) is one blast,
## played each time the body puts its lips to the horn, so sound and body
## never drift apart; anything that ends the blowing early cuts the blast off.
##
## The body is posed bone by bone with ClimbPose's angles (see ClimbPose.apply)
## over the rig's standing pose; while walking there the body plays its own
## walk. Used by Player (blow_horn) and Villager (the guard's _watch).

## How long one blast of the clip lasts (seconds), and the part of it loud
## enough that the blower is still seen blowing (the rest is the fade).
const BLAST := 3.0
const HEARD := 2.75
## The second blast is a little weaker: the blower is short of breath (dB).
const SECOND_DB := -0.5
## When each blast starts, in seconds after the blower reaches the horn.
const BLASTS := [0.6, 5.0]
## How long the blowing takes from reaching the horn until standing easy again.
const LENGTH := 8.3

## Where the blower's feet are while blowing, in the horn's own space (see
## VillageProps.build_war_horn: the mouthpiece points along +x, its tip at
## x 0.95, 1.14 m up). Leaning in puts the mouth right at the tip.
const STAND := Vector3(1.44, 0.0, -0.1)
## The lips on the rig standing (a little below where the breath puffs out,
## Breath.MOUTH): leaning in for a blast puts them on the mouthpiece's tip.
const LIPS := Breath.MOUTH + Vector3(0.0, -0.09, 0.0)
## How far back from the mouthpiece the blower steps to catch their breath.
const BACK := 0.6
## The walk round the horn keeps this far from its middle (metres), the
## cradle and the blower's body together.
const CLEAR := 1.3

## The poses, in ClimbPose's angles (degrees, positive = forward / up / bent).
const POSES := {
	"stand": {},
	# Upright, chest out, chin up, hands coming up to the horn: a deep breath in.
	"inhale": {"spine": -3.0, "chest": -9.0, "head": -14.0, "arm": 60.0, "elbow": 40.0},
	# Leaning in, lips on the mouthpiece, both hands steadying the horn from below it.
	"blow": {"spine": 16.0, "chest": 3.0, "head": -12.0, "arm": 112.0, "elbow": 22.0},
	# The air running out: the chest sinks, the back bends a little more.
	"blow_end": {"hips_y": -0.01, "spine": 18.0, "chest": 9.0, "head": -10.0, "arm": 108.0, "elbow": 24.0,
		"knee_l": 3.0, "knee_r": 3.0},
	# Stepped back, hands off the horn, bent over and panting.
	"gasp": {"hips_y": -0.04, "spine": 18.0, "chest": 6.0, "head": 12.0, "arm": 14.0, "elbow": 25.0,
		"hip_l": 14.0, "hip_r": 4.0, "knee_l": 22.0, "knee_r": 10.0},
}
## The blowing, from reaching the horn: [seconds, pose, metres back from STAND].
const KEYS := [
	[0.00, "stand", BACK],
	[0.35, "inhale", 0.2],
	[0.60, "blow", 0.0],
	[3.35, "blow_end", 0.0],
	[3.80, "gasp", BACK],
	[4.45, "gasp", BACK],
	[4.75, "inhale", 0.2],
	[5.00, "blow", 0.0],
	[7.75, "blow_end", 0.0],
	[8.30, "stand", BACK],
]
## While catching breath the chest heaves this many times a second.
const PANT := 2.2

## Called with the blast's number (0, 1) the moment it starts to sound.
var on_blast := Callable()
## Called once if the blowing ends before it is over, with how many blasts sounded.
var on_stop := Callable()

var level: Outdoor
## Where the blower's feet are while blowing, and the way out from the
## mouthpiece to there (the way the blower steps back).
var stand := Vector3.INF
var away := Vector3.RIGHT
## The walk there, ending where the blowing starts (BACK behind `stand`).
var route: Array[Vector3] = []
## Seconds since reaching the horn (negative: still walking there).
var time := 0.0
var walking := true
var done := false
var stopped := false
var blasts := 0
var _sound: AudioStreamPlayer
var _place := Vector3.ZERO


## Where the blower's feet are at the horn standing at `at`, and the way out
## from its mouthpiece (see STAND).
static func mouth_spot(o: Outdoor, at: Vector3) -> Vector3:
	return at + Basis(Vector3.UP, WarHorn.facing(o, at)) * STAND


## Begins blowing the horn of `o` for a body standing at `from`.
static func begin(o: Outdoor, from: Vector3) -> HornBlow:
	var b := HornBlow.new()
	b.level = o
	var at := o.war_horn_at
	b.stand = mouth_spot(o, at)
	b.away = Basis(Vector3.UP, WarHorn.facing(o, at)) * Vector3.RIGHT
	b.route = way_round(at, Vector3(from.x, at.y, from.z), b.stand + b.away * BACK)
	b._place = Vector3(from.x, at.y, from.z)
	return b


## The walk from `from` to `to` that keeps CLEAR of the horn at `at`: straight
## when it can, else by a point beside the horn on the side the walker is on.
static func way_round(at: Vector3, from: Vector3, to: Vector3) -> Array[Vector3]:
	var way: Array[Vector3] = []
	var flat_at := Vector2(at.x, at.z)
	var near := Geometry2D.get_closest_point_to_segment(flat_at, Vector2(from.x, from.z), Vector2(to.x, to.z))
	if near.distance_to(flat_at) < CLEAR:
		var out := Vector2(to.x - at.x, to.z - at.z).normalized()
		var side := Vector2(-out.y, out.x)
		if side.dot(Vector2(from.x - at.x, from.z - at.z)) < 0.0:
			side = -side
		var past := flat_at + (side + out * 0.3).normalized() * (CLEAR + 0.7)
		way.append(Vector3(past.x, at.y, past.y))
	way.append(to)
	return way


## Metres left to walk to the horn from where the body is now.
func walk_left() -> float:
	var left := 0.0
	var from := _place
	for p in route:
		left += from.distance_to(p)
		from = p
	return left


## Seconds until the blowing is over, walking at `speed`.
func seconds_left(speed: float) -> float:
	return (walk_left() / maxf(speed, 0.1) if walking else 0.0) + LENGTH - maxf(time, 0.0)


## One tick: walks on at `speed` (m/s), or poses and blows. Returns where the
## body's feet are now ("pos"), the way it faces ("face"), whether it is
## still walking there ("walking": the body plays its walk) and the pose
## (ClimbPose angles) while blowing.
func step(delta: float, speed: float) -> Dictionary:
	if not done and not is_instance_valid(level):
		stop()
	if done:
		return {"pos": _place, "face": -away, "walking": false, "pose": {}}
	if walking:
		var go := speed * delta
		var heading := -away
		while go > 0.0 and not route.is_empty():
			var to: Vector3 = route[0]
			var d := _place.distance_to(to)
			if d > 0.001:
				heading = (to - _place) / d
			if d <= go:
				_place = to
				go -= d
				route.remove_at(0)
			else:
				_place += heading * go
				go = 0.0
		if not route.is_empty():
			return {"pos": _place, "face": heading, "walking": true, "pose": {}}
		walking = false
		time = 0.0
	time += delta
	if blasts < BLASTS.size() and time >= float(BLASTS[blasts]):
		_blast(blasts)
		blasts += 1
	if time >= LENGTH:
		done = true
	var state := at_time(time)
	_place = stand + away * float(state.back)
	return {"pos": _place, "face": -away, "walking": false, "pose": state.pose}


## The pose and how far back from the mouthpiece (metres) at `t` seconds
## after reaching the horn.
static func at_time(t: float) -> Dictionary:
	t = clampf(t, 0.0, LENGTH)
	for i in range(1, KEYS.size()):
		var k0: Array = KEYS[i - 1]
		var k1: Array = KEYS[i]
		if t <= float(k1[0]) or i == KEYS.size() - 1:
			var u := smoothstep(0.0, 1.0, clampf((t - float(k0[0])) / (float(k1[0]) - float(k0[0])), 0.0, 1.0))
			var pose := ClimbPose.mix(POSES[k0[1]], POSES[k1[1]], u)
			if k0[1] == "gasp" or k1[1] == "gasp":
				# Panting: the chest heaves and the head bobs with it.
				var heave := sin(t * TAU * PANT) * (1.0 if k0[1] == k1[1] else 0.5)
				pose["chest"] = float(pose.get("chest", 0.0)) + 5.0 * heave
				pose["head"] = float(pose.get("head", 0.0)) + 3.0 * heave
			return {"pose": pose, "back": lerpf(float(k0[2]), float(k1[2]), u)}
	return {"pose": {}, "back": BACK}


## Whether the blower's lips are on the horn at `t` (a blast sounds).
static func blowing_at(t: float) -> bool:
	for start: float in BLASTS:
		if t >= start and t < start + HEARD:
			return true
	return false


func _blast(i: int) -> void:
	var p := Sfx.play(level, WarHorn.SOUND, WarHorn.VOLUME_DB + (SECOND_DB if i > 0 else 0.0), level.war_horn_at)
	if p != null:
		# The horn keeps its pitch, so the blast lasts just as long as the blowing.
		p.pitch_scale = 1.0
	_sound = p
	if on_blast.is_valid():
		on_blast.call(i)


## Ends the blowing early (the blower walks off, is struck, called away): the
## blast that sounds dies away at once. Nothing happens once it is over.
func stop() -> void:
	if done or stopped:
		return
	stopped = true
	done = true
	if is_instance_valid(_sound) and _sound.playing:
		var fade := _sound.create_tween()
		fade.tween_property(_sound, "volume_db", -40.0, 0.25)
		fade.tween_callback(_sound.queue_free)
	if on_stop.is_valid():
		on_stop.call(blasts)

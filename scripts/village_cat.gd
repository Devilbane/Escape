class_name VillageCat
extends Node3D
## The village cat. It strolls about the smithy's end of the village, sits and looks around with
## a flicking tail, and when it is tired of walking it pads to its perch, the barrel by the stacked
## granite blocks beside the smithy, crouches, jumps up onto its lid, treads a spot, and curls up to
## sleep. At night it sleeps there all night; in winter it naps longer. Asleep it breathes slowly,
## twitches an ear and flicks the tip of its tail now and then, and when the hero comes near it purrs
## (its breathing gets deeper and a little quicker). When it has slept enough it stretches, hops down
## and strolls off again.
##
## It never fights, cannot be hurt and is no obstacle: it has no collision and takes no room (a hero
## can walk straight through it). It wears no snow: it is a small warm animal and its fur stays bare
## in winter. A village without the big smithy, or without a barrel by its stones, has no cat.
##
## The model is built here from a few low-poly shapes (ellipsoids, cylinders and cones) in a
## ginger coat with a cream chest and paws, so nothing is imported. Every pose (walk, sit, crouch,
## leap, stretch, curl) is laid over its joints in _pose, one blend value for each.

## Ground speed (m/s) of a stroll and how far (tiles) from its perch it roams.
const WALK := 1.1
const ROAM := 7
## The cat's size against a real one (the world is big, like the hedgehog's).
const SIZE := 1.15
## How high (metres, above the straight line) the leap arcs, and how long it takes (seconds).
const LEAP_ARC := 0.55
const LEAP_TIME := 0.75
const CROUCH_TIME := 0.5
## It purrs when the hero is nearer than this (metres).
const PURR_RANGE := 5.5
## The purr's loudest (dB) with the hero beside the cat: soft, under the village's other sounds.
const PURR_DB := -17.0
const PURR_SOUND := "res://assets/sounds/cat_purr.wav"
## Night naps all night: from this hour in the evening till this hour in the morning.
const BEDTIME := 21.5
const RISE := 6.0
## How long a nap lasts (seconds), by day and in winter.
const NAP := Vector2(70.0, 140.0)
const NAP_WINTER := Vector2(130.0, 240.0)
## It naps after this many strolls, and in winter after this many.
const STROLLS := 2
const STROLLS_WINTER := 1

const GINGER := Color(0.86, 0.5, 0.2)
const DARK := Color(0.62, 0.3, 0.1)
const CREAM := Color(0.88, 0.78, 0.64)

## "stroll" (walking somewhere), "sit" (looking about), "to_perch" (walking to its foot),
## "crouch", "leap" (up onto its perch), "settle" (treading its spot), "nap", "stretch" and
## "hop" (down again).
var state := "sit"
var level: Level
## The middle of the barrel's lid (world), the way out from it, and the spot on the ground in
## front of it the cat leaps from.
var perch_top: Vector3
var out_dir: Vector3
var foot: Vector3
var _rng := RandomNumberGenerator.new()
var _homed := false
var _path: Array[Vector3] = []
var _timer := 0.0
var _clock := 0.0
var _phase := 0.0
var _waiting := 0.0
var _strolls := 0
## Joints.
var _body: Node3D
var _chest: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _belly: MeshInstance3D
## The model of the cat curled up asleep (see CatSleeper) and its flicking tail tip and ears.
var _sleeper: Node3D
var _sleep_tip: Node3D
var _sleep_ears: Array[Node3D] = []
## Blend values, 0 to 1: curled up, sitting, crouched / flying, stretching, eyes shut.
var _curl := 0.0
var _sit := 0.0
var _leap := 0.0
var _stretch := 0.0
var _sleepy := 0.0
## How far through a leap it is (0 to 1), and from where to where, up (true) or down.
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _arc := 0.0
var _flick := 0.0
var _flick_in := 3.0
var _twitch := 0.0
var _twitch_in := 5.0
var _purring := 0.0
## The purr's sound: a soft loop that fades in as the hero comes near and out as they go (see _hum).
var _purr_player: AudioStreamPlayer3D
## The phase of its breathing; it speeds up a little only while it purrs.
var _breath := 0.0


## Where it lives: the top of the perch's face and the way out from it (both world).
func setup(owner_level: Level, top: Vector3, out: Vector3) -> void:
	level = owner_level
	perch_top = top
	out_dir = Vector3(out.x, 0.0, out.z).normalized()
	_rng.seed = hash(Vector2(top.x, top.z)) + 41


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	_build()
	visible = false
	_begin("sit", 1.0)
	_pose(0.0)


## Finds its perch's foot and takes its place there, once the village's tiles are laid out (they
## are not yet while its buildings go up). True when it is at home.
func home() -> bool:
	if _homed:
		return foot != Vector3.INF
	if level == null or level.astar == null or level.astar.region.size == Vector2i.ZERO:
		return false
	_homed = true
	foot = _find_foot()
	if foot == Vector3.INF:
		set_physics_process(false)
		return false
	global_position = foot + out_dir * 1.6
	rotation.y = atan2(out_dir.x, out_dir.z)
	visible = true
	return true


## The open ground nearest its perch from which it leaps up (out in front of it first, then to its
## sides and back), in the middle of a free tile. Infinity when its perch is walled in.
func _find_foot() -> Vector3:
	var base := Vector3(perch_top.x, 0.0, perch_top.z)
	var side := Vector3(-out_dir.z, 0.0, out_dir.x)
	var ways: Array[Vector3] = [out_dir, side, -side, (out_dir + side).normalized(), (out_dir - side).normalized(), -out_dir]
	var d := 1.2
	while d <= 4.5:
		for way in ways:
			var p := base + way * d
			if _open(level.world_to_cell(p)) and _roomy(p):
				return p
		d += 0.2
	return Vector3.INF


## Whether the tiles round a spot (a metre each way) are open too, so the cat does not stand in a wall's edge.
func _roomy(p: Vector3) -> bool:
	for off in [Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(0, 0, -0.6)]:
		if not _open(level.world_to_cell(p + off)):
			return false
	return true


# --- The model -----------------------------------------------------------------

func _ball(parent: Node3D, at: Vector3, radius: Vector3, colour: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 6
	m.mesh = s
	m.scale = radius * 2.0
	m.position = at
	m.material_override = _paint(colour)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _stick(parent: Node3D, at: Vector3, radius: float, length: float, colour: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	m.position = at
	m.material_override = _paint(colour)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _paint(colour: Color) -> StandardMaterial3D:
	# The coat's colours get the fur texture; the eyes, nose and ears' insides stay plain.
	return CatSleeper.paint(colour, colour in [GINGER, DARK, CREAM])


func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = at
	parent.add_child(j)
	return j


## A cat that stands about 0.45 m at the head and 0.65 m long, facing +z, its feet at y = 0.
func _build() -> void:
	var root := Node3D.new()
	root.scale = Vector3.ONE * SIZE
	add_child(root)
	var asleep := CatSleeper.build(root)
	_sleeper = asleep.root
	_sleep_tip = asleep.tip
	_sleep_ears.assign(asleep.ears)
	_sleeper.visible = false
	_body = _joint(root, Vector3(0, 0.3, 0))
	# The trunk: one long ellipsoid, a lighter belly under it and a cream bib at the chest.
	_ball(_body, Vector3(0, 0, 0), Vector3(0.17, 0.16, 0.34), GINGER)
	_belly = _ball(_body, Vector3(0, -0.06, 0.03), Vector3(0.12, 0.09, 0.26), CREAM)
	_chest = _joint(_body, Vector3(0, 0, 0.2))
	_ball(_chest, Vector3(0, -0.03, 0.06), Vector3(0.11, 0.12, 0.1), CREAM)
	# Darker stripes over the back.
	for z in [-0.14, -0.04, 0.06, 0.16]:
		_ball(_body, Vector3(0, 0.145 - absf(z) * 0.12, z), Vector3(0.07, 0.035, 0.035), DARK)
	# The head on a short neck, with muzzle, nose, ears and eyes.
	_head = _joint(_chest, Vector3(0, 0.1, 0.1))
	_ball(_head, Vector3.ZERO, Vector3(0.115, 0.1, 0.1), GINGER)
	_ball(_head, Vector3(0, -0.03, 0.075), Vector3(0.06, 0.045, 0.045), CREAM)
	_ball(_head, Vector3(0, -0.012, 0.115), Vector3(0.022, 0.016, 0.014), Color(0.9, 0.5, 0.52))
	for side: float in [-1.0, 1.0]:
		var ear := _joint(_head, Vector3(side * 0.06, 0.08, -0.01))
		ear.rotation.z = -side * 0.35
		var cone := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.05
		c.height = 0.1
		c.radial_segments = 4
		c.rings = 1
		cone.mesh = c
		cone.position = Vector3(0, 0.04, 0)
		cone.material_override = _paint(GINGER)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ear.add_child(cone)
		var inner := MeshInstance3D.new()
		var ic := CylinderMesh.new()
		ic.top_radius = 0.0
		ic.bottom_radius = 0.03
		ic.height = 0.07
		ic.radial_segments = 4
		ic.rings = 1
		inner.mesh = ic
		inner.position = Vector3(0, 0.03, 0.02)
		inner.material_override = _paint(Color(0.9, 0.62, 0.6))
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ear.add_child(inner)
		_ears.append(ear)
		var eye := _ball(_head, Vector3(side * 0.05, 0.02, 0.085), Vector3(0.026, 0.03, 0.014), Color(0.35, 0.65, 0.2))
		_eyes.append(eye)
		var pupil := _ball(eye, Vector3(0, 0, 0.4), Vector3(0.35, 0.8, 0.5), Color(0.04, 0.04, 0.04))
		pupil.scale = Vector3(0.35, 0.8, 0.5)
	# Four legs, hanging from the hips and shoulders, each ending in a cream paw. The order:
	# front left, front right, back left, back right.
	for z: float in [0.17, -0.17]:
		for side: float in [-1.0, 1.0]:
			var hip := _joint(_body, Vector3(side * 0.085, -0.04, z))
			_stick(hip, Vector3(0, -0.115, 0), 0.034 if z < 0.0 else 0.03, 0.23, GINGER)
			_ball(hip, Vector3(0, -0.245, 0.018), Vector3(0.04, 0.03, 0.055), CREAM)
			_legs.append(hip)
	# The tail: four joints in a chain, each a short stick, hanging back and up from the rump.
	var parent := _joint(_body, Vector3(0, 0.03, -0.3))
	parent.rotation.x = -0.9
	for i in 4:
		_stick(parent, Vector3(0, 0, 0), 0.026 - i * 0.002, 0.001, GINGER)
		var seg := _stick(parent, Vector3(0, 0, -0.06), 0.026 - i * 0.003, 0.14, GINGER if i < 3 else DARK)
		seg.rotation.x = PI * 0.5
		_tail.append(parent)
		parent = _joint(parent, Vector3(0, 0, -0.13))


# --- Its day ---------------------------------------------------------------------

func _begin(new_state: String, time: float) -> void:
	state = new_state
	_timer = time


## Whether it is night, when the cat sleeps on its perch.
func is_night() -> bool:
	if level.get("night") == true:
		return true
	var h: float = level.get("hour")
	return h >= BEDTIME or (h >= 0.0 and h < RISE)


func is_winter() -> bool:
	return Weather.is_winter(int(level.get("season_day")))


## Whether it is asleep, curled up, right now.
func is_asleep() -> bool:
	return state == "nap"


## Sends it to its perch now, whatever it was doing (for the tests and for the night).
func go_to_bed() -> void:
	if state in ["to_perch", "crouch", "leap", "settle", "nap"]:
		return
	_strolls = 0
	if _set_path(foot):
		_begin("to_perch", 0.0)
	else:
		_begin("crouch", CROUCH_TIME)
		_from = global_position
		_to = perch_top


## Its small paw prints in the snow (see SnowTrail); only while it walks.
var _trail := SnowTrail.new("cat")


func _physics_process(delta: float) -> void:
	if level == null or level.player == null or not home():
		return
	if state == "stroll" or state == "to_perch":
		_trail.follow(level, global_position)
	var hero: Node3D = level.player
	var away := _flat(global_position - hero.global_position).length()
	# Far from the hero nobody sees it: it keeps still.
	if away > 90.0:
		return
	_clock += delta
	_breath += delta * (1.7 + 0.8 * _purring)
	# Asleep on its perch it lies exactly on its face, whatever else moves.
	if state == "nap" or state == "settle":
		global_position = perch_top
	var calm_hero: bool = away < PURR_RANGE and not hero.get("dead")
	_purring = move_toward(_purring, 1.0 if (calm_hero and state == "nap") else 0.0, delta * 2.0)
	_hum()
	_flick_in -= delta
	if _flick_in <= 0.0:
		_flick = 1.0
		_flick_in = _rng.randf_range(2.5, 7.0)
	_flick = move_toward(_flick, 0.0, delta * 1.2)
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch = 1.0
		_twitch_in = _rng.randf_range(3.0, 9.0)
	_twitch = move_toward(_twitch, 0.0, delta * 4.0)
	match state:
		"sit":
			_timer -= delta
			_face_hero(hero, away, delta)
			if _timer <= 0.0:
				_next()
		"stroll":
			_walk(delta)
			if _path.is_empty():
				_strolls += 1
				_begin("sit", _rng.randf_range(3.0, 8.0))
		"to_perch":
			_walk(delta)
			if _path.is_empty():
				_begin("crouch", CROUCH_TIME)
				_from = global_position
				_to = perch_top
		"crouch":
			_timer -= delta
			WalkRules.turn(self, perch_top - global_position, delta, 12.0)
			if _timer <= 0.0:
				_arc = 0.0
				_begin("leap", LEAP_TIME)
		"leap":
			_fly(delta, true)
		"settle":
			_timer -= delta
			_phase += delta * 5.0
			WalkRules.turn(self, out_dir, delta, 3.0)
			if _timer <= 0.0:
				var napping := _rng.randf_range(NAP_WINTER.x, NAP_WINTER.y) if is_winter() else _rng.randf_range(NAP.x, NAP.y)
				_begin("nap", napping)
		"nap":
			_timer -= delta
			if _timer <= 0.0 and not is_night():
				_begin("stretch", 2.2)
		"stretch":
			_timer -= delta
			if _timer <= 0.0:
				_from = global_position
				_to = foot
				_arc = 0.0
				_begin("hop", LEAP_TIME * 0.9)
		"hop":
			_fly(delta, false)
	_pose(delta)


## The purr as sound: a looped soft rumble from the cat, fading in with how near the hero is (the
## same share as the purr of its body) and out again, stopped when it is quiet. It is played from the
## cat's spot without fading with the camera's distance, so the volume is chosen here.
func _hum() -> void:
	if _purring < 0.02:
		if _purr_player != null and _purr_player.playing:
			_purr_player.stop()
		return
	if _purr_player == null:
		var stream := (load(PURR_SOUND) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		_purr_player = AudioStreamPlayer3D.new()
		_purr_player.stream = stream
		_purr_player.bus = Sfx.BUS
		_purr_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		_purr_player.panning_strength = 1.0
		add_child(_purr_player)
	_purr_player.volume_db = PURR_DB + linear_to_db(_purring)
	if not _purr_player.playing:
		_purr_player.play()


## Face the hero when they are near, a calm cat watching. Otherwise stay as it is.
func _face_hero(hero: Node3D, away: float, delta: float) -> void:
	if away < 4.0:
		WalkRules.turn(self, hero.global_position - global_position, delta, 3.0)


## What it does next after sitting: stroll somewhere, or go to its perch when it is bedtime or
## it has walked enough.
func _next() -> void:
	var enough := _strolls >= (STROLLS_WINTER if is_winter() else STROLLS)
	if is_night() or enough:
		go_to_bed()
		return
	if _rng.randf() < 0.25:
		_begin("sit", _rng.randf_range(2.0, 5.0))
		return
	if _set_path(_nearby(ROAM)):
		_begin("stroll", 0.0)
	else:
		_begin("sit", 3.0)


## Walks along its path.
func _walk(delta: float) -> void:
	if _path.is_empty():
		return
	var to := _flat(_path[0] - global_position)
	var step := WALK * delta
	var target := Vector3(_path[0].x, 0.0, _path[0].z) if to.length() <= step else global_position + to.normalized() * step
	if not WalkRules.can_step(level, global_position, target):
		_waiting += delta
		if _waiting >= WalkRules.MAKE_WAY:
			_waiting = 0.0
			var goal: Vector3 = _path[_path.size() - 1]
			if not _set_path(goal):
				_path.clear()
		return
	_waiting = 0.0
	global_position = target
	if to.length() <= step:
		_path.pop_front()
	_phase += step * 7.5
	WalkRules.turn(self, to, delta, WalkRules.TURN_RATE * 1.2)


## One tick of a leap up onto its perch or a hop down from it, along an arc.
func _fly(delta: float, up: bool) -> void:
	var span := LEAP_TIME if up else LEAP_TIME * 0.9
	_arc = minf(1.0, _arc + delta / span)
	var t := _arc
	# Ease out: the push is strong at the start and it glides to the landing.
	var e := 1.0 - (1.0 - t) * (1.0 - t) * (0.6 + 0.4 * (1.0 - t))
	var rise := 4.0 * t * (1.0 - t) * (LEAP_ARC if up else LEAP_ARC * 0.5)
	global_position = _from.lerp(_to, e if up else t) + Vector3(0, rise, 0)
	var flat := _flat(_to - _from)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 14.0))
	if _arc >= 1.0:
		global_position = _to
		if up:
			# Lands on its perch facing out, treads a little and settles.
			_begin("settle", 1.8)
			_strolls = 0
		else:
			_begin("sit", _rng.randf_range(2.0, 4.0))


# --- Its pose ----------------------------------------------------------------------

func _pose(delta: float) -> void:
	var k := 1.0 if delta <= 0.0 else delta
	var curled := state in ["nap", "settle"]
	var sitting := state == "sit"
	var flying := state in ["crouch", "leap", "hop"]
	_curl = move_toward(_curl, 1.0 if curled and (state == "nap" or _timer < 1.0) else 0.0, k * 0.9) if delta > 0.0 else (1.0 if state == "nap" else 0.0)
	_sit = move_toward(_sit, 1.0 if sitting else 0.0, k * 2.5) if delta > 0.0 else (1.0 if sitting else 0.0)
	_stretch = move_toward(_stretch, 1.0 if state == "stretch" else 0.0, k * 1.6) if delta > 0.0 else (1.0 if state == "stretch" else 0.0)
	_sleepy = move_toward(_sleepy, 1.0 if state in ["nap", "settle"] else 0.0, k * 0.8) if delta > 0.0 else (1.0 if state == "nap" else 0.0)
	var up := 1.0 - _curl
	var walking := state in ["stroll", "to_perch"]
	# What each blend means. Values at rest (stood still on its feet):
	var body_y := 0.3
	var body_pitch := 0.0
	var body_roll := 0.0
	var leg_swing := Vector4.ZERO
	var head_pitch := 0.0
	var head_yaw := 0.0
	var tail_curve := 0.0
	var breathe := 1.0
	if walking:
		# Diagonal pairs swing together: front left with back right.
		var s := sin(_phase)
		leg_swing = Vector4(s, -s, -s, s) * 0.55
		body_y += absf(sin(_phase)) * 0.012
		body_roll = sin(_phase) * 0.025
		head_pitch = -0.05 + sin(_phase * 2.0) * 0.03
	if flying:
		var windup := 0.0
		var stretched := 0.0
		if state == "crouch":
			windup = clampf(1.0 - _timer / CROUCH_TIME, 0.0, 1.0)
		else:
			stretched = sin(_arc * PI)
		body_y -= windup * 0.1
		body_pitch = windup * 0.25 - stretched * 0.55 if state == "leap" else windup * 0.25 + stretched * 0.35
		leg_swing = Vector4(-0.3, -0.3, 0.25, 0.25) * windup + (Vector4(-1.1, -1.1, 1.0, 1.0) if state == "leap" else Vector4(0.9, 0.9, -0.5, -0.5)) * stretched
		head_pitch = -stretched * 0.35 if state == "leap" else 0.0
		tail_curve = stretched * 0.3
	# Sitting: nose up, rump low, front legs straight, back legs folded forward.
	body_pitch += _sit * 0.75
	body_y -= _sit * 0.1
	leg_swing += Vector4(-0.75, -0.75, 1.45, 1.45) * _sit
	head_pitch -= _sit * 0.75
	# Looking about while it sits: the head turns slowly one way, then the other.
	if state == "sit":
		head_yaw = sin(_clock * 0.8) * 0.6
	# Stretching: front legs reaching forward, the rump up, the head down between them.
	body_pitch -= _stretch * 0.4
	leg_swing += Vector4(-1.0, -1.0, -0.15, -0.15) * _stretch
	head_pitch += _stretch * 0.5
	body_y -= _stretch * 0.03
	# Purring: only the breath gets a little deeper. The body itself never moves up or down (a fast
	# hum sampled by the physics ticks looked like bouncing), it lies still on its perch.
	breathe = 1.0 + sin(_breath) * (0.012 + 0.012 * _purring)
	# Curled up: lowered, round and short, the legs tucked in, the head laid beside the tail.
	body_y = lerpf(body_y, 0.13, _curl)
	var body_scale := Vector3(1.0 + 0.3 * _curl, 1.0 - 0.28 * _curl, 1.0 - 0.38 * _curl)
	body_scale.y *= breathe
	# Curled up it is the sleeping model instead: it breathes, its tail tip flicks, an ear twitches.
	var asleep := _curl >= 0.5
	_sleeper.visible = asleep
	_body.visible = not asleep
	if asleep:
		var lie := smoothstep(0.5, 1.0, _curl)
		_sleeper.scale = Vector3(1.0, lerpf(0.75, 1.0, lie) * breathe, 1.0)
		_sleep_tip.rotation.y = sin(_flick * PI * 3.0) * _flick * 0.45
		_sleep_ears[1].rotation.z = 0.45 + sin(_twitch * PI) * 0.25
		_sleep_ears[0].rotation.z = -0.45
	_body.position = Vector3(0.0, body_y, 0.0)
	_body.rotation = Vector3(body_pitch * up, 0.0, body_roll * up)
	_body.scale = body_scale
	var i := 0
	for leg in _legs:
		var swing: float = leg_swing[i] * up
		leg.rotation.x = swing
		leg.scale = Vector3(1.0, lerpf(1.0, 0.3, _curl), 1.0)
		leg.position.y = lerpf(-0.04, 0.06, _curl)
		i += 1
	# Curled, the head rests on the front paws, turned a little to the side.
	_head.rotation = Vector3(lerpf(head_pitch, 0.5, _curl), lerpf(head_yaw, 1.0, _curl), lerpf(0.0, 0.5, _curl))
	_head.position = Vector3(lerpf(0.0, 0.07, _curl), lerpf(0.1, -0.02, _curl), lerpf(0.1, 0.02, _curl))
	for eye in _eyes:
		var shut := clampf(_sleepy * 1.4 - 0.1, 0.0, 1.0)
		eye.scale.y = 0.06 * lerpf(1.0, 0.12, shut)
	# Ears: pricked, a twitch every so often, flat when it sleeps.
	for n in _ears.size():
		var side := -1.0 if n == 0 else 1.0
		_ears[n].rotation.z = -side * (0.35 + lerpf(0.0, 0.5, _sleepy))
		if n == 0:
			_ears[n].rotation.z += sin(_twitch * PI) * 0.35 * up + sin(_twitch * PI) * 0.15
		_ears[n].rotation.x = -0.25 * _sleepy
	# The tail: swings gently from side to side as it walks, hangs low when it sits, curls round
	# the body when it sleeps, and now and then the tip flicks.
	var n := 0
	var sway := sin(_clock * 1.3) * 0.18
	if walking:
		sway = sin(_phase * 0.5) * 0.15
	for seg in _tail:
		var f := float(n) / 3.0
		var side_turn := sway * (0.5 + f) * up
		var flick := sin(_flick * PI * 3.0) * _flick * 0.9 * f
		side_turn += flick
		# Curled it sweeps round to lie along the side of the body.
		side_turn = lerpf(side_turn, 0.75, _curl)
		var lift := lerpf(0.3 - f * 0.1, 0.0, _curl)
		if n == 0:
			lift = lerpf(-0.9 + _sit * 0.6 + tail_curve * 0.3, 0.0, _curl)
		seg.rotation = Vector3(lift, side_turn, 0.0)
		n += 1
	_tail[0].position = Vector3(0, lerpf(0.03, -0.02, _curl), lerpf(-0.3, -0.18, _curl))


## A free tile within a few tiles of the perch's foot.
func _nearby(radius: int) -> Vector3:
	var home: Vector2i = level.world_to_cell(foot)
	for i in 20:
		var c := home + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if _open(c):
			return level.cell_to_world(c) + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
	return foot


func _open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return level.is_open(c) if level.has_method("is_open") else not level.astar.is_point_solid(c)


func _set_path(target: Vector3) -> bool:
	_path.assign(WalkRules.path(level, global_position, target, _rng))
	return not _path.is_empty()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

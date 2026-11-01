class_name Pet
extends Node3D
## The hero's fox: a wild fox of the meadows that the hero has won over with
## sausages (see Animal, "curious"). From then on it goes with the hero
## everywhere, in the open air, in the village and down in the dungeon, and
## climbs the stairs right behind them.
##
## It does not cling to the hero's heels. While the hero stays within its
## leash (LEASH metres) it lounges about: it stands and looks around, sits,
## lies down when the hero rests, strolls about, trots in a circle round the
## hero and noses at things nearby. Only when the hero walks off does it
## follow, and it runs when it has fallen behind.
##
## Its nose is what makes it useful: every level hides a few ingredients in
## the ground (see Level.hidden_finds) that the hero cannot see. When one lies
## within the fox's nose range it runs over, sniffs, digs it up and leaves it
## lying there for the hero to pick up.
##
## The fox never fights, cannot be hurt and takes up no room, like the wild
## animals. If it falls too far behind it catches up at once.
##
## The model only has Idle, Walk, Gallop and Eating, so sitting and lying
## down are poses laid over Idle bone by bone (POSES), faded in and out.

## The food that wins a fox over, and how many it must eat to trust the hero.
const FOOD := "wurst"
const TRUST_NEEDED := 3
## Where the foxes live, for the hint on buying a sausage and the
## compendium. tests/fox.gd checks that the map still agrees: the fox
## meadow lies west of the village square, next to the woodland pond.
const WHERE := "Füchse leben auf der Wiese am Waldteich westlich vom Dorf, am Weg, der vom Friedhof herunterkommt. Trag eine Wurst bei dir, dann kommt ein Fuchs zu dir."
## Following: the fox closes up to FOLLOW_GAP, runs from RUN_FROM, and stays
## put (lounging) as long as the hero is no more than LEASH away.
const FOLLOW_GAP := 2.6
const LEASH := 6.0
const RUN_FROM := 7.0
## Beyond this the fox catches up at once (it knows a short cut).
const CATCH_UP := 24.0
const WALK_SPEED := 2.2
const AMBLE_SPEED := 1.5
const RUN_SPEED := 7.5
## While lounging it strolls no further than this from the hero, and circles
## the hero at this distance.
const ROAM := 4.5
const CIRCLE := 2.5
## The hero must stand still this long before the fox lies down.
const LIE_AFTER := 4.0
## How far its nose reaches (metres from the fox), how long it digs, and how
## long it rests its nose after a find (seconds).
const NOSE_RANGE := 14.0
const DIG_TIME := 2.0
const SNIFF_REST := 12.0
## A spot it cannot reach in this time is given up for now.
const GIVE_UP := 10.0
const SCALE := 0.4
const RUN_ANIM := 5.0
## Sitting and lying: extra bone turns (degrees about the bone's own x axis)
## over Idle, and "drop" lowers the body (in the model's own units).
const POSES := {
	"sit": {"drop": -0.9, "bones": {"Back": -38, "FrontShoulder.L": 55, "FrontShoulder.R": 55,
		"BackUpperLeg.L": 85, "BackUpperLeg.R": 85, "BackLowerLeg.L": 60, "BackLowerLeg.R": 60,
		"Neck1": -30, "Tail1": 30}},
	"lie": {"drop": -1.4, "bones": {"FrontShoulder.L": -70, "FrontShoulder.R": -70,
		"BackUpperLeg.L": 90, "BackUpperLeg.R": 90, "BackLowerLeg.L": 70, "BackLowerLeg.R": 70,
		"Neck1": 15, "Tail1": 25}},
}
## How fast a pose fades in or out (share per second).
const POSE_SPEED := 2.2
## What it does while lounging, and how likely each is.
const ACTS := {"stand": 2.0, "sit": 3.0, "lie": 2.5, "wander": 2.0, "circle": 1.5, "sniff": 2.5}

signal dug_up(id: String, pos: Vector3)

var level: Level
## "follow", "lounge" (near the hero, see _act), "seek" (on the way to a
## find), "dig", or "climb" (on the stairs behind the hero, see climb).
var state := "follow"
## While lounging: "stand", "sit", "lie", "wander", "circle" or "sniff".
var _act := "stand"
var _model: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _path: Array[Vector3] = []
var _repath := 0.0
var _rest := SNIFF_REST * 0.5
var _timer := 0.0
var _target: Dictionary = {}
var _current_anim := ""
var _placed := false
## How far each pose is faded in (0..1), and how long the hero stood still.
var _pose := {"sit": 0.0, "lie": 0.0}
var _hero_still := 0.0
var _climb: Tween = null
var _posed_bones: Array[int] = []
var _rng := RandomNumberGenerator.new()


func setup(owner_level: Level) -> void:
	level = owner_level
	_rng.randomize()


func _ready() -> void:
	_model = load("res://assets/animals/Fox.glb").instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	_skeleton = _model.find_child("Skeleton3D", true, false)
	for p in POSES.values():
		for bone in p.bones.keys() + ["Body"]:
			var i := _skeleton.find_bone(bone)
			if i >= 0 and not _posed_bones.has(i):
				_posed_bones.append(i)
	for a in ["Idle", "Walk", "Gallop", "Eating"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	# Advanced by hand in _process, so the poses can be laid over it.
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("Idle")


func play(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.25)


func _hero() -> Node3D:
	return level.player if level else null


## The pose it is in now: "sit", "lie" or "" (standing or moving).
func pose() -> String:
	if state == "lounge" and _path.is_empty() and _act in POSES:
		return _act
	return ""


## How far a pose is faded in right now (0..1).
func pose_weight(pose_name: String) -> float:
	return _pose.get(pose_name, 0.0)


func _process(delta: float) -> void:
	# Bones the animation leaves alone keep what the last frame's pose did to
	# them: back to rest first, so the poses never add up.
	for i in _posed_bones:
		_skeleton.set_bone_pose(i, _skeleton.get_bone_rest(i))
	_anim.advance(delta)
	var want := pose()
	for p in _pose:
		_pose[p] = move_toward(_pose[p], 1.0 if p == want else 0.0, delta * POSE_SPEED)
		if _pose[p] > 0.0:
			_lay_pose(POSES[p], ease(_pose[p], -1.8))


## Lays a pose over the animation, faded in by `weight`.
func _lay_pose(p: Dictionary, weight: float) -> void:
	for bone in p.bones:
		var i := _skeleton.find_bone(bone)
		if i >= 0:
			var turn := Quaternion(Vector3.RIGHT, deg_to_rad(p.bones[bone]) * weight)
			_skeleton.set_bone_pose_rotation(i, _skeleton.get_bone_pose_rotation(i) * turn)
	var body := _skeleton.find_bone("Body")
	if body >= 0:
		_skeleton.set_bone_pose_position(body, _skeleton.get_bone_pose_position(body) + Vector3(0, p.drop * weight, 0))


func _physics_process(delta: float) -> void:
	var hero := _hero()
	if hero == null or state == "climb":
		return
	var gap := _flat(hero.global_position - global_position).length()
	if not _placed or gap > CATCH_UP:
		_beside_hero(hero)
		_placed = true
		return
	var hero_speed := Vector2(hero.velocity.x, hero.velocity.z).length() if hero is CharacterBody3D else 0.0
	_hero_still = _hero_still + delta if hero_speed < 0.3 else 0.0
	_rest -= delta
	match state:
		"follow":
			if _rest <= 0.0 and _sniff():
				return
			if gap > FOLLOW_GAP:
				_repath -= delta
				if _repath <= 0.0 or _path.is_empty():
					_repath = 0.4
					_set_path(hero.global_position)
				_walk(delta, RUN_SPEED if gap > RUN_FROM else WALK_SPEED, hero)
			else:
				_path.clear()
				state = "lounge"
				_begin_act("stand", hero)
		"lounge":
			if gap > LEASH:
				# The hero walks off: up and after them.
				_path.clear()
				state = "follow"
				return
			if _rest <= 0.0 and _sniff():
				return
			_lounge(delta, hero)
		"seek":
			_timer -= delta
			if not level.hidden_finds.has(_target) or _timer <= 0.0:
				_back_to_hero()
				return
			_walk(delta, RUN_SPEED, null)
			if _path.is_empty():
				state = "dig"
				_timer = DIG_TIME
				_anim.speed_scale = 1.4
				play("Eating")
		"dig":
			_timer -= delta
			if _timer <= 0.0:
				_dig_up()


# --- Lounging ---------------------------------------------------------------------

## One step of whatever it is doing near the hero.
func _lounge(delta: float, hero: Node3D) -> void:
	_timer -= delta
	if not _path.is_empty():
		_walk(delta, AMBLE_SPEED, null)
		if _path.is_empty():
			if _act == "circle" and _timer > 0.0:
				_circle_step(hero)
			elif _act == "sniff":
				_anim.speed_scale = 1.0
				play("Eating")
				_timer = _rng.randf_range(1.5, 3.0)
			else:
				_begin_act("stand", hero)
		return
	match _act:
		"stand":
			_anim.speed_scale = 1.0
			play("Idle")
			_turn_to(hero.global_position - global_position, delta * 0.4)
		"sit", "lie":
			_anim.speed_scale = 0.5
			play("Idle")
			if _act == "lie" and _hero_still < 0.5:
				# The hero moves about: no time for a nap.
				_timer = minf(_timer, 0.5)
	if _timer <= 0.0:
		_next_act(hero)


## Picks what to do next, by the weights in ACTS.
func _next_act(hero: Node3D) -> void:
	var weights := ACTS.duplicate()
	if _hero_still < LIE_AFTER:
		weights.erase("lie")
	weights.erase(_act)
	var total := 0.0
	for a in weights:
		total += weights[a]
	var roll := _rng.randf() * total
	for a in weights:
		roll -= weights[a]
		if roll <= 0.0:
			_begin_act(a, hero)
			return
	_begin_act("stand", hero)


func _begin_act(act: String, hero: Node3D) -> void:
	_act = act
	_path.clear()
	_anim.speed_scale = 1.0
	match act:
		"stand":
			_timer = _rng.randf_range(1.5, 3.5)
		"sit":
			_timer = _rng.randf_range(4.0, 9.0)
		"lie":
			_timer = _rng.randf_range(8.0, 16.0)
		"wander":
			_timer = 8.0
			if not _go_to(_spot_near(hero.global_position, 1.8, ROAM)):
				_begin_act("stand", hero)
		"circle":
			_timer = _rng.randf_range(5.0, 9.0)
			_circle_step(hero)
		"sniff":
			_timer = 8.0
			if not _go_to(_something_to_sniff(hero)):
				_begin_act("stand", hero)


## On round the hero: the next point a quarter turn further.
func _circle_step(hero: Node3D) -> void:
	var from := _flat(global_position - hero.global_position)
	var angle := atan2(from.x, from.z) + PI / 2.5
	var p := hero.global_position + Vector3(sin(angle), 0, cos(angle)) * CIRCLE
	if not _go_to(p):
		_begin_act("stand", hero)


## A thing nearby worth a sniff: a barrel, crate or chest, a bench, a
## villager's spot, or else a patch of ground.
func _something_to_sniff(hero: Node3D) -> Vector3:
	var things: Array[Vector3] = []
	for list in [level.interactables, level.stations]:
		for o in list:
			var pos = o.get("pos")
			if pos is Vector3 and _flat(pos - hero.global_position).length() < ROAM:
				things.append(pos)
	if not things.is_empty() and _rng.randf() < 0.7:
		var thing: Vector3 = things[_rng.randi() % things.size()]
		# Up to it, not into it.
		return thing + _flat(global_position - thing).normalized() * 1.1
	return _spot_near(global_position, 1.0, 2.5)


## A free spot `near`..`far` metres from `centre`, still on the leash.
func _spot_near(centre: Vector3, near: float, far: float) -> Vector3:
	var hero := _hero()
	for i in 12:
		var angle := _rng.randf() * TAU
		var p := centre + Vector3(sin(angle), 0, cos(angle)) * _rng.randf_range(near, far)
		if _open(level.world_to_cell(p)) and _flat(p - hero.global_position).length() < LEASH - 1.0:
			return p
	return global_position


func _go_to(p: Vector3) -> bool:
	if _flat(p - global_position).length() < 0.3 or not _open(level.world_to_cell(p)):
		return false
	return _set_path(p)


# --- Stairs ---------------------------------------------------------------------

## Up (or down) the stairs right behind the hero: a run to the first point,
## then step by step, `delay` seconds after the hero. It stays there until
## the next level (or arrive()), or until `done` lets it go on; `first_time`
## sets how long the first stretch takes instead of a run.
func climb(points: Array, step_time: float, delay: float, done := false, first_time := -1.0) -> void:
	if points.is_empty():
		return
	state = "climb"
	_path.clear()
	if _climb:
		_climb.kill()
	_climb = create_tween()
	_climb.tween_interval(delay)
	var from := global_position
	_climb.tween_callback(func():
		play("Gallop" if _flat(points[0] - global_position).length() > 3.0 else "Walk"))
	for i in points.size():
		var p: Vector3 = points[i]
		var t := step_time
		if i == 0:
			t = first_time if first_time > 0.0 else clampf(_flat(p - from).length() / RUN_SPEED, 0.15, 1.2)
		_climb.tween_callback(func():
			play("Walk")
			_turn_to(p - global_position, 1.0))
		_climb.tween_property(self, "global_position", p, t)
		from = p
	if done:
		_climb.tween_callback(func():
			state = "follow"
			global_position.y = 0.0)


## Arrived somewhere new with the hero: it turns up at the hero's side.
func arrive() -> void:
	if _climb:
		_climb.kill()
	_placed = false
	state = "follow"
	_path.clear()


## Puts the fox down on open ground right next to the hero.
func _beside_hero(hero: Node3D) -> void:
	var here := level.world_to_cell(hero.global_position)
	var spot := hero.global_position
	var near: Array[Vector3] = [hero.global_position + hero.global_transform.basis.z * 1.5, hero.global_position - hero.global_transform.basis.z * 1.5]
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		near.append(level.cell_to_world(here + d))
	for p in near:
		if _open(level.world_to_cell(p)):
			spot = p
			break
	global_position = Vector3(spot.x, 0.0, spot.z)
	_path.clear()
	state = "follow"


## Looks for a hidden ingredient in nose range. True when it found one and
## is on its way.
func _sniff() -> bool:
	var best: Dictionary = {}
	var best_d := NOSE_RANGE
	for f in level.hidden_finds:
		var d := _flat(level.cell_to_world(f.cell) - global_position).length()
		if d < best_d:
			best_d = d
			best = f
	if best.is_empty():
		_rest = 1.0
		return false
	if not _set_path(level.cell_to_world(best.cell)):
		# Out of reach (behind a wall or a gate): ignore it for a while.
		_rest = SNIFF_REST
		return false
	_target = best
	state = "seek"
	_timer = GIVE_UP
	Effects.float_text(level, global_position + Vector3(0, 1.6, 0), "?", Color(1.0, 0.75, 0.35, 0.95))
	return true


func _dig_up() -> void:
	_anim.speed_scale = 1.0
	var pos := level.cell_to_world(_target.cell)
	if level.hidden_finds.has(_target):
		level.hidden_finds.erase(_target)
		var dirt := Effects.make_sparkles(Color(0.45, 0.32, 0.18), true)
		dirt.position = pos + Vector3(0, 0.3, 0)
		level.add_child(dirt)
		dug_up.emit(_target.id, pos)
	_back_to_hero()


func _back_to_hero() -> void:
	_target = {}
	_path.clear()
	_rest = SNIFF_REST
	state = "follow"


func is_digging() -> bool:
	return state == "dig"


func _walk(delta: float, speed: float, hero: Node3D) -> void:
	if _path.is_empty():
		return
	if hero:
		# Keeps up with a running hero.
		var hero_speed: float = Vector2(hero.velocity.x, hero.velocity.z).length() if hero is CharacterBody3D else 0.0
		speed = maxf(speed, hero_speed * 1.1)
	var to := _flat(_path[0] - global_position)
	var step := speed * delta
	if to.length() <= step:
		global_position = Vector3(_path[0].x, global_position.y, _path[0].z)
		_path.pop_front()
	else:
		global_position += to.normalized() * step
	_turn_to(to, delta)
	if speed > WALK_SPEED * 1.5:
		play("Gallop")
		_anim.speed_scale = clampf(speed / RUN_ANIM, 0.6, 2.0)
	else:
		play("Walk")
		_anim.speed_scale = 1.0


func _set_path(target: Vector3) -> bool:
	_path.clear()
	var from := level.world_to_cell(global_position)
	var to := level.world_to_cell(target)
	if from == to:
		_path.append(Vector3(target.x, global_position.y, target.z))
		return true
	var cells: Array[Vector2i] = level.grid_path(from, to)
	for c in cells.slice(1, cells.size() - 1):
		_path.append(level.cell_to_world(c))
	if not cells.is_empty():
		_path.append(Vector3(target.x, global_position.y, target.z))
	return not _path.is_empty()


func _open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return level.is_open(c) if level.has_method("is_open") else level._walkable(c) and not level.astar.is_point_solid(c)


func _turn_to(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 7.0))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

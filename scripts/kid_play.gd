class_name KidPlay
extends RefCounted
## Two village children at play (Pip and Pippi, see "pal" in Villager.ROLES): they chase each other
## over the meadow, whoever catches the other hands the chase over, and now and then one of them
## stops to show off a cartwheel or a somersault, the other one cheering.
##
## The tricks are procedural: the body is turned about the hip (see pose) while it travels over the
## ground in physics ticks, so the model needs no extra animation clips.
## Rules (see can_join and tick): no play at night, during an alarm, indoors or away from the
## children's own ground; the play ends the moment anybody talks to a child, and nobody runs or
## flips into the hero, a wall, a shut gate or ground that is not open (FarmAnimal.may_stand).

## How far from where the play began the children may go (metres).
const ARENA := 5.0
## How far from the child's home tile the play may begin (tiles).
const HOME_RANGE := 14
## The chaser has caught the other within this distance (metres).
const CATCH := 1.0
## Nobody runs or flips closer to the hero than this (metres), and no trick begins this near.
const HERO_ROOM := 1.6
const HERO_ROOM_TRICK := 2.8
## Seconds the chaser needs again before the next catch counts.
const TAG_PAUSE := 1.4
## A run lasts this long before a trick (seconds), and the cheer after it.
const RUN_TIME := Vector2(3.5, 7.0)
const CHEER_TIME := 1.0
## How long each trick takes, how far it carries the child (metres), and how high the hips rise.
const TRICKS := {
	"cartwheel": {"time": 1.2, "dist": 2.2, "rise": 0.12},
	"somersault": {"time": 1.3, "dist": 1.6, "rise": 0.04},
}
## Directions tried for a run away (degrees off straight away from the chaser).
const FLEE_TURNS := [0, 35, -35, 70, -70, 110, -110, 150, -150]

var v: Villager
var pal: Villager
var active := false
## "run", "trick" or "cheer".
var phase := "run"
var chaser := false
var trick := ""
var _clock := 0.0
var _trick_from := Vector3.ZERO
var _trick_dir := Vector3.ZERO
var _tag_pause := 0.0
## Where the play began: the arena is round it.
var centre := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init(child: Villager) -> void:
	v = child
	_rng.seed = hash(child.role) + 17


## The other one of the pair, or null when they are not out in the village.
static func pal_of(child: Villager) -> Villager:
	var want: String = child._info.get("pal", "")
	if want == "" or child.level == null:
		return null
	for o: Villager in child.level.villagers:
		if o.role == want and o != child:
			return o
	return null


## Whether it is a time and place for play: day, no alarm, outdoors, awake, not afraid, not in a
## chat, a song, a bubble or the herald's crowd.
static func fine_day(child: Villager) -> bool:
	if child.night or child.at_home or not child.visible or child.eaten or child.threat != null:
		return false
	if child.level.village_alarm.raised or child.endangered() or child.singing or child.shaken:
		return false
	return child.chat_partner == null and child._bubble_time <= 0.0 and child._listen_to == Vector3.INF


## Whether `child` can join a game now: it is at its work or idle (or on its way to play).
static func can_join(child: Villager) -> bool:
	if not fine_day(child) or child.keeps_spot():
		return false
	var then: String = child.get_meta("then", "")
	if child._task == "walk":
		return then in ["work", "idle", "play"]
	return child._task in ["work", "idle", "play"]


## Starts the play as the chaser and pulls the pal in. False when there is nobody to play with.
func begin() -> bool:
	pal = pal_of(v)
	if pal == null or not can_join(v) or not can_join(pal):
		return false
	if pal._task == "play" and pal._kid != null and pal._kid.active:
		return false
	if absi(v.home.x - v.level.world_to_cell(v.global_position).x) > HOME_RANGE \
			or absi(v.home.y - v.level.world_to_cell(v.global_position).y) > HOME_RANGE:
		return false
	centre = (v.global_position + pal.global_position) * 0.5
	chaser = true
	active = true
	phase = "run"
	_clock = _rng.randf_range(RUN_TIME.x, RUN_TIME.y)
	pal.join_play(v, centre, v._task_time)
	return true


## Joins a game another child began, as the one who is chased.
func join(other: Villager, at: Vector3) -> void:
	pal = other
	centre = at
	chaser = false
	active = true
	phase = "run"
	_clock = _rng.randf_range(RUN_TIME.x, RUN_TIME.y)


## Ends the game for this child: the body stands upright again.
func stop() -> void:
	active = false
	phase = "run"
	trick = ""
	reset_pose()


func tricking() -> bool:
	return active and phase == "trick"


func reset_pose() -> void:
	var s: float = v._model.scale.x
	v._model.basis = Basis.from_scale(Vector3(s, s, s))
	v._model.position = Vector3.ZERO


## One physics tick of play. False when the game is over for this child.
func tick(delta: float) -> bool:
	if not active or pal == null or not is_instance_valid(pal):
		return false
	if not fine_day(v) or pal._kid == null or not pal._kid.active or pal._task != "play":
		return false
	if Vector2(v.global_position.x - centre.x, v.global_position.z - centre.z).length() > ARENA + 2.0:
		return false
	_tag_pause = maxf(0.0, _tag_pause - delta)
	match phase:
		"run":
			_run(delta)
		"trick":
			_do_trick(delta)
		"cheer":
			_cheer(delta)
	return true


func _hero_flat(point: Vector3) -> float:
	var hero: Node3D = v.level.player
	return Vector2(point.x - hero.global_position.x, point.z - hero.global_position.z).length()


## Open ground the child may stand on, inside the arena, clear of the hero.
func _fits(point: Vector3, room := HERO_ROOM) -> bool:
	if Vector2(point.x - centre.x, point.z - centre.z).length() > ARENA:
		return false
	if v.blocked_at(point) or _hero_flat(point) < room:
		return false
	return FarmAnimal.may_stand(v.level, v.level.world_to_cell(point))


func _run(delta: float) -> void:
	var to := pal.global_position - v.global_position
	to.y = 0.0
	var pal_runs: bool = pal._kid.phase == "run"
	if chaser:
		if to.length() <= CATCH:
			v._turn_to(to, delta)
			if pal_runs and _tag_pause <= 0.0:
				# Caught: now the other one chases.
				chaser = false
				pal._kid.chaser = true
				_tag_pause = TAG_PAUSE
				pal._kid._tag_pause = TAG_PAUSE
				v.play("Cheer", 0.1)
			else:
				v.play("Idle")
		else:
			_step(to.normalized(), Villager.RUN_SPEED, delta)
	elif pal._kid.chaser and pal_runs:
		_flee(-to.normalized(), delta)
	else:
		# Watching the other do a trick, or waiting to be chased.
		v._turn_to(to, delta)
		v.play("Cheer" if pal._kid.phase != "run" else "Idle")
	_clock -= delta
	if _clock <= 0.0:
		_start_trick()


func _step(direction: Vector3, speed: float, delta: float) -> void:
	var walked: float = v._stride("Running_A", speed)
	var target := v.global_position + direction * walked * delta
	if _hero_flat(target) < HERO_ROOM or not v._move_to(target):
		v.play("Idle")
		return
	v._turn_to(direction, delta)


## Away from the chaser: straight, or round whatever is in the way.
func _flee(away: Vector3, delta: float) -> void:
	var speed: float = Villager.RUN_SPEED * 0.92
	for turn_by: int in FLEE_TURNS:
		var way := away.rotated(Vector3.UP, deg_to_rad(turn_by))
		if _fits(v.global_position + way * 0.9):
			_step(way, speed, delta)
			return
	v.play("Idle")


func _start_trick() -> void:
	if _hero_flat(v.global_position) < HERO_ROOM_TRICK:
		_clock = 1.0
		return
	var kinds := TRICKS.keys()
	trick = kinds[_rng.randi() % kinds.size()]
	var info: Dictionary = TRICKS[trick]
	var forward := Vector3(sin(v.rotation.y), 0, cos(v.rotation.y))
	var side := Vector3(forward.z, 0, -forward.x)
	# A cartwheel goes to either side, a somersault forwards (or back, when forwards is blocked).
	var along := side if trick == "cartwheel" else forward
	var options: Array[Vector3] = []
	options.append(along)
	options.append(-along)
	if _rng.randf() < 0.5:
		options.reverse()
	for dir: Vector3 in options:
		if _clear_way(dir, info.dist):
			_trick_dir = dir
			_trick_from = v.global_position
			_clock = 0.0
			phase = "trick"
			return
	trick = ""
	_clock = 1.5


## Whether the whole way a trick covers is open ground.
func _clear_way(dir: Vector3, dist: float) -> bool:
	for i in 5:
		if not _fits(v.global_position + dir * dist * (i + 1) / 5.0, HERO_ROOM_TRICK * 0.6):
			return false
	return true


func _do_trick(delta: float) -> void:
	var info: Dictionary = TRICKS[trick]
	_clock += delta
	var t := clampf(_clock / float(info.time), 0.0, 1.0)
	var hero_in_way := _hero_flat(v.global_position) < HERO_ROOM * 0.8
	if hero_in_way:
		_end_trick()
		return
	# Arms up at the start and the end (as in a cartwheel's first and last pose), the hands on
	# the ground between.
	# A somersault is a tucked roll on the ground: arms up, crouch, curl up, roll, sit up, stand.
	if trick == "somersault":
		v.play("Cheer" if t < 0.1 or t > 0.92 else "Sit_Floor_Pose", 0.08)
	else:
		v.play("Cheer" if t < 0.12 or t > 0.9 else "Jump_Idle", 0.08)
	var eased := t * t * (3.0 - 2.0 * t)
	var where := _trick_from + _trick_dir * float(info.dist) * eased
	if not v._move_to(where):
		_end_trick()
		return
	v._turn_to(_trick_dir if trick == "somersault" else Vector3(-_trick_dir.z, 0, _trick_dir.x), delta)
	var p := pose(trick, t, _trick_dir, v.rotation.y, v._model.scale.x)
	v._model.basis = p.basis
	v._model.position = p.position
	if t >= 1.0:
		_end_trick()


func _end_trick() -> void:
	reset_pose()
	trick = ""
	phase = "cheer"
	_clock = CHEER_TIME
	v.play("Cheer", 0.1)


func _cheer(delta: float) -> void:
	_clock -= delta
	v.play("Cheer")
	if _clock <= 0.0:
		phase = "run"
		_clock = _rng.randf_range(RUN_TIME.x, RUN_TIME.y)


## The model's basis and position (in the body's own frame) at `t` (0 to 1) through a trick, with
## the body facing `yaw` and travelling along `dir` (flat, world space) and the model `s` times
## full size. A cartwheel turns about the way the child faces, head first towards the way it
## goes; a somersault turns head over heels forwards. Both turn about the hips and lift them.
static func pose(kind: String, t: float, dir: Vector3, yaw: float, s: float) -> Dictionary:
	var info: Dictionary = TRICKS[kind]
	var eased := t * t * (3.0 - 2.0 * t)
	var turn := TAU * eased
	var axis := Vector3.RIGHT
	var angle := turn
	if kind == "cartwheel":
		# The body's own frame: +Z forward (the way it faces), +X to the left of it.
		var local := dir.rotated(Vector3.UP, -yaw)
		axis = Vector3.BACK
		angle = -signf(local.x) * turn
	else:
		angle = signf(dir.rotated(Vector3.UP, -yaw).z) * turn
	var spin := Basis(axis, angle)
	# The roll is low and curled up: the body is squashed to a ball between the crouch at the
	# start and the one at the end.
	var squash := 1.0
	var pivot := 0.95 * s
	if kind == "somersault":
		squash = 1.0 - 0.45 * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.8, 1.0, t))
		pivot = 0.95 * s * squash
	var rise := float(info.rise) * 4.0 * t * (1.0 - t)
	var basis := spin * Basis.from_scale(Vector3(s, s * squash, s))
	var hip := Vector3(0, pivot, 0)
	return {"basis": basis, "position": hip - spin * hip + Vector3(0, rise, 0)}

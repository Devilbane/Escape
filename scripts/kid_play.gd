class_name KidPlay
extends RefCounted
## Two village children at play (Pip and Pippi, see "pal" in Villager.ROLES): they chase each other
## over the meadow, whoever catches the other hands the chase over, and now and then one of them
## stops to show off a cartwheel or a somersault, the other one cheering.
##
## The tricks are procedural: the body is turned about the hip (see pose) while it travels over the
## ground in physics ticks, so the model needs no extra animation clips.
## When the snow lies thick (see snowy) they play in it instead: they build a snowman (see
## Snowman), throw snowballs at each other (and now and then at a grown-up close by, or the hero),
## dodge to the side between throws, and run round their snowman and cheer in front of it. Between
## the fights they make snow angels (SnowGames.angel), roll big balls of snow along and leave them
## standing (SnowGames.lump), and take a run-up and slide over the snow.
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
## Snow play: the snow must lie this thick; the children keep between these distances apart for a
## snowball fight (metres); a throw takes this long, the ball leaves the hand at RELEASE; they
## throw again after a pause picked between THROW_PAUSE; after a few throws they run round the
## snowman for a while. A throw goes at somebody else close by (within OTHERS metres) with
## OTHER_CHANCE, at the hero (within OTHERS metres too) with HERO_CHANCE, and misses with MISS_CHANCE.
const SNOW_FROM := 0.45
const FIGHT_RANGE := Vector2(3.0, 6.5)
const THROW_TIME := 0.9
const RELEASE := 0.38
const THROW_PAUSE := Vector2(0.9, 2.0)
const THROWS := Vector2i(5, 9)
const ROUND_TIME := Vector2(4.5, 7.0)
const OTHERS := 12.0
const OTHER_CHANCE := 0.4
const HERO_CHANCE := 0.22
const MISS_CHANCE := 0.3
## The games in the snow after the first fight, and how often each is picked (see _begin_phase).
const SNOW_GAMES := {"ball": 3.0, "angel": 1.0, "roll": 1.2, "slide": 1.2}
## A snow angel: how long lying down (and getting up) takes, how long the arms and legs sweep, and
## how long the body is (metres, at full size).
const ANGEL_DOWN := 0.45
const ANGEL_SWEEP := Vector2(2.4, 3.4)
const BODY := 1.8
## Rolling a ball of snow: how far (metres), how fast, and how big it grows (its radius, metres).
const ROLL_DIST := Vector2(2.0, 3.2)
const ROLL_SPEED := 0.85
const LUMP := Vector2(0.14, 0.42)
## A slide: the run-up (seconds, at this speed), then the glide (seconds), slowing to a stop.
const SLIDE_RUN := 0.7
const SLIDE_SPEED := 2.6
const SLIDE_TIME := 1.3
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
## Snow play: the snowman, seconds till the next throw, how far into a throw (-1 when not
## throwing), whether the ball has left the hand, at whom, throws left before a run round the
## snowman, which way round, and a dodge to the side.
var snowman: Snowman
var _next_throw := 0.0
var _throw_t := -1.0
var _thrown := false
var _target: Node3D
var _throws_left := 0
var _round_dir := 1.0
var _dodge := Vector3.ZERO
var _dodge_t := 0.0
## The other games in the snow: how many games so far, where to (flat), how long the angel's
## sweep lasts and whether its shape is left yet, how far is still to roll and the ball, and the
## speed of the glide.
var _games := 0
var _way := Vector3.ZERO
var _sweep := 0.0
var _marked := false
var _roll_left := 0.0
var _roll_all := 1.0
var _lump: MeshInstance3D
var _glide := 0.0


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


## Whether the snow lies thick enough to play in.
static func snowy(child: Villager) -> bool:
	var lvl = child.level
	return lvl is Outdoor and lvl.snow != null and lvl.snow.amount >= SNOW_FROM


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
	if snowy(v):
		snowman = Snowman.ensure(v.level, centre)
		if snowman != null:
			centre = snowman.global_position
	chaser = true
	active = true
	_begin_phase()
	pal.join_play(v, centre, v._task_time)
	return true


## The first phase of a game: a snowball fight in the snow, a chase otherwise.
func _begin_phase() -> void:
	if snowy(v):
		var game := "ball" if _games == 0 else _pick_game()
		_games += 1
		if (game == "angel" and _start_angel()) or (game == "roll" and _start_roll()) \
				or (game == "slide" and _start_slide()):
			return
		phase = "ball"
		_throws_left = _rng.randi_range(THROWS.x, THROWS.y)
		_next_throw = _rng.randf_range(0.5, 1.5)
		_throw_t = -1.0
		_round_dir = 1.0 if chaser else -1.0
	else:
		phase = "run"
		_clock = _rng.randf_range(RUN_TIME.x, RUN_TIME.y)


## Joins a game another child began, as the one who is chased.
func join(other: Villager, at: Vector3) -> void:
	pal = other
	centre = at
	chaser = false
	active = true
	snowman = v.level.snowman if v.level is Outdoor else null
	_begin_phase()


## Ends the game for this child: the body stands upright again.
func stop() -> void:
	active = false
	phase = "run"
	trick = ""
	_throw_t = -1.0
	_lump = null
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
		"ball":
			_ball(delta)
		"round":
			_round(delta)
		"angel":
			_angel(delta)
		"roll":
			_roll(delta)
		"slide":
			_slide(delta)
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
		_begin_phase()


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


# --- Play in the snow ----------------------------------------------------------

## A snowball fight: keep a throw apart, dodge to the side, throw now and then.
func _ball(delta: float) -> void:
	if _throw_t >= 0.0:
		_throwing(delta)
		return
	var to := pal.global_position - v.global_position
	to.y = 0.0
	var d := to.length()
	if d < FIGHT_RANGE.x:
		_flee(-to.normalized(), delta)
	elif d > FIGHT_RANGE.y:
		_step(to.normalized(), Villager.RUN_SPEED * 0.6, delta)
	elif _dodge_t > 0.0:
		_dodge_t -= delta
		if _fits(v.global_position + _dodge * 0.6):
			_step(_dodge, Villager.RUN_SPEED * 0.7, delta)
		else:
			_dodge_t = 0.0
	else:
		v._turn_to(to, delta)
		v.play("Idle")
	_next_throw -= delta
	if _next_throw > 0.0:
		return
	if _throws_left <= 0 and snowman != null and is_instance_valid(snowman):
		phase = "round"
		_clock = _rng.randf_range(ROUND_TIME.x, ROUND_TIME.y)
		return
	_target = _pick_target()
	_throw_t = 0.0
	_thrown = false
	_throws_left -= 1
	_next_throw = _rng.randf_range(THROW_PAUSE.x, THROW_PAUSE.y)
	v._current_anim = "Throw"
	v._anim.play("Throw", 0.1)


## Mid-throw: face the target, let go of the ball at RELEASE, then a dodge to one side.
func _throwing(delta: float) -> void:
	_throw_t += delta
	if _target != null and is_instance_valid(_target):
		v._turn_to(_target.global_position - v.global_position, delta)
	if not _thrown and _throw_t >= RELEASE:
		_thrown = true
		if _target != null and is_instance_valid(_target):
			Sfx.play(v, "swing", -16.0, v.global_position, 1.3)
			Snowball.throw(v.level, v.hand_at(), _target, v, _rng.randf() < MISS_CHANCE)
	if _throw_t >= THROW_TIME:
		_throw_t = -1.0
		v.play("Idle", 0.15)
		var forward := Vector3(sin(v.rotation.y), 0, cos(v.rotation.y))
		_dodge = Vector3(forward.z, 0, -forward.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_dodge_t = _rng.randf_range(0.3, 0.7)


## Whom the next ball is for: mostly the friend, sometimes a grown-up close by, rarely the hero.
func _pick_target() -> Node3D:
	var roll := _rng.randf()
	var hero: Node3D = v.level.player
	if roll < HERO_CHANCE and hero != null and _hero_flat(v.global_position) < OTHERS \
			and v.level.has_line_of_sight(v.global_position, hero.global_position):
		return hero
	if roll < HERO_CHANCE + OTHER_CHANCE:
		var other := grown_up_near(v, OTHERS)
		if other != null:
			return other
	return pal


## A grown-up near `child` who may be pelted: out and about, not in a talk or a fight, in sight.
static func grown_up_near(child: Villager, reach: float) -> Villager:
	var best: Villager = null
	var best_d := reach
	for o: Villager in child.level.villagers:
		if o == child or o._info.get("pal", "") != "" or o.at_home or not o.visible or o.night:
			continue
		if o.chat_partner != null or o.threat != null or o._task in ["fight", "defend", "home", "hide"]:
			continue
		var d := o.global_position.distance_to(child.global_position)
		if d < best_d and child.level.has_line_of_sight(child.global_position, o.global_position):
			best = o
			best_d = d
	return best


## A run round the snowman, the two of them going opposite ways, then a cheer in front of him.
func _round(delta: float) -> void:
	if snowman == null or not is_instance_valid(snowman):
		_begin_phase()
		return
	var off := v.global_position - snowman.global_position
	off.y = 0.0
	if off.length() < 0.05:
		off = Vector3(1, 0, 0)
	var around := Vector3(-off.z, 0, off.x).normalized() * _round_dir
	var pull := -off.normalized() * (off.length() - Snowman.RING) * 1.5
	var way := (around + pull).normalized()
	if _fits(v.global_position + way * 0.6, HERO_ROOM):
		_step(way, Villager.RUN_SPEED * 0.85, delta)
	else:
		_round_dir = -_round_dir
		v.play("Idle")
	_clock -= delta
	if _clock <= 0.0:
		v._turn_to(-off, delta)
		phase = "cheer"
		_clock = CHEER_TIME * 1.5
		v.play("Cheer", 0.1)


# --- More games in the snow ----------------------------------------------------

## The next game in the snow, by the weights of SNOW_GAMES.
func _pick_game() -> String:
	var total := 0.0
	for g: String in SNOW_GAMES:
		total += float(SNOW_GAMES[g])
	var roll := _rng.randf() * total
	for g: String in SNOW_GAMES:
		roll -= float(SNOW_GAMES[g])
		if roll <= 0.0:
			return g
	return "ball"


func _forward() -> Vector3:
	return Vector3(sin(v.rotation.y), 0, cos(v.rotation.y))


## Ways to go from here, turned round the way the child faces, the first towards the middle of
## the play when `inward`.
func _ways(inward := false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var start := _forward()
	if inward:
		var to := centre - v.global_position
		to.y = 0.0
		if to.length() > 0.3:
			start = to.normalized()
	for turn_by: int in [0, 45, -45, 90, -90, 135, -135, 180]:
		out.append(start.rotated(Vector3.UP, deg_to_rad(turn_by + _rng.randf_range(-15.0, 15.0))))
	return out


## Lies down on the back in the snow where there is room behind for the whole body.
func _start_angel() -> bool:
	if _hero_flat(v.global_position) < HERO_ROOM_TRICK:
		return false
	var length := BODY * v._model.scale.x
	for dir in _ways():
		# `dir` is where the head goes: the child looks the other way.
		if _clear_way(dir, length):
			_way = dir
			v.rotation.y = atan2(-dir.x, -dir.z)
			_sweep = _rng.randf_range(ANGEL_SWEEP.x, ANGEL_SWEEP.y)
			_marked = false
			_clock = 0.0
			phase = "angel"
			return true
	return false


## Down on the back, arms and legs sweeping, up again, and there is the angel.
func _angel(delta: float) -> void:
	_clock += delta
	var total := ANGEL_DOWN * 2.0 + _sweep
	var down := smoothstep(0.0, ANGEL_DOWN, _clock) * (1.0 - smoothstep(total - ANGEL_DOWN, total, _clock))
	# Waving arms while lying flat sweeps the wings.
	v.play("Cheer" if down > 0.95 else "Idle", 0.15)
	var p := lie_pose(down, v._model.scale.x)
	v._model.basis = p.basis
	v._model.position = p.position
	if not _marked and _clock >= total - ANGEL_DOWN:
		_marked = true
		var length := BODY * v._model.scale.x
		SnowGames.angel(v.level, v.global_position + _way * length * 0.5, _way, length)
	if _clock >= total:
		reset_pose()
		phase = "cheer"
		_clock = CHEER_TIME
		v.play("Cheer", 0.1)


## The model lying back (`down` 0 standing to 1 flat on the back) about the feet, the face to the
## sky, the back a little over the snow, at `s` times full size.
static func lie_pose(down: float, s: float) -> Dictionary:
	var tilt := Basis(Vector3.RIGHT, -PI * 0.5 * down)
	return {"basis": tilt * Basis.from_scale(Vector3(s, s, s)), "position": Vector3(0, 0.14 * s * down, 0)}


## Starts a ball of snow at the feet and pushes it off where there is room to roll it.
func _start_roll() -> bool:
	var dist := _rng.randf_range(ROLL_DIST.x, ROLL_DIST.y)
	for dir in _ways(true):
		if _clear_way(dir, dist + LUMP.y * 2.0 + 0.4):
			_way = dir
			_roll_all = dist
			_roll_left = dist
			_lump = SnowGames.lump(v.level, _lump_spot(LUMP.x), LUMP.x)
			_clock = 0.0
			phase = "roll"
			return true
	return false


func _lump_spot(radius: float) -> Vector3:
	return v.global_position + _way * (0.35 + radius)


## Bent over the ball, pushing it along slowly as it grows; it stays where the push ends.
func _roll(delta: float) -> void:
	if _lump == null or not is_instance_valid(_lump):
		_end_game()
		return
	var walked: float = v._stride("Walking_A", ROLL_SPEED)
	var step := walked * delta
	var target := v.global_position + _way * step
	var grown := lerpf(LUMP.x, LUMP.y, 1.0 - _roll_left / _roll_all)
	var ahead := target + _way * (0.35 + grown * 2.0)
	if _roll_left <= 0.0 or _hero_flat(ahead) < HERO_ROOM or not _fits(ahead) or not v._move_to(target):
		_lump = null
		_end_game()
		return
	v._turn_to(_way, delta)
	_roll_left -= step
	SnowGames.set_lump(_lump, _lump_spot(grown), grown)
	# Leaning into the push.
	var s: float = v._model.scale.x
	v._model.basis = Basis(Vector3.RIGHT, 0.35) * Basis.from_scale(Vector3(s, s, s))


## A run-up where there is a long clear way, then a glide over the snow.
func _start_slide() -> bool:
	var total := SLIDE_SPEED * (SLIDE_RUN + SLIDE_TIME * 0.5) + 0.4
	for dir in _ways(true):
		if _clear_way(dir, total):
			_way = dir
			_clock = 0.0
			_glide = 0.0
			phase = "slide"
			return true
	return false


func _slide(delta: float) -> void:
	_clock += delta
	var speed := 0.0
	if _clock < SLIDE_RUN:
		speed = v._stride("Running_A", SLIDE_SPEED)
		_glide = speed
	else:
		var t := (_clock - SLIDE_RUN) / SLIDE_TIME
		if t >= 1.0:
			_end_game()
			return
		speed = _glide * (1.0 - t)
		# Arms out, leaning back a little, the feet gliding.
		v.play("Cheer", 0.1)
		var s: float = v._model.scale.x
		v._model.basis = Basis(Vector3.RIGHT, -0.22 * (1.0 - t * 0.5)) * Basis.from_scale(Vector3(s, s, s))
	var target := v.global_position + _way * speed * delta
	if _hero_flat(target) < HERO_ROOM or not _fits(target) or not v._move_to(target):
		_end_game()
		return
	v._turn_to(_way, delta)


## A snow game is over: upright again, and a cheer.
func _end_game() -> void:
	reset_pose()
	phase = "cheer"
	_clock = CHEER_TIME
	v.play("Cheer", 0.1)

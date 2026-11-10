class_name FarmAnimal
extends Node3D
## The village's own animals (see VillageFarm): a flock of geese, a few goats
## and two dogs wander about Lindenhain. They are ambient only: they cannot be
## hurt, never fight and take up no room (no collision, no tile of their own),
## and they only ever stop on open grass or path, never on the front step of a
## building or at a gate, so they never block a door or a way.
##
## - Geese keep together. They graze, waddle after one another and, when the
##   hero comes close (less close while the hero sneaks), they flap off in a
##   body, and one that is startled startles the rest of the flock.
## - Goats graze and trot away from a hero who comes close.
## - Cows and the bull graze and walk off from a hero who comes close. Sheep act like goats.
## - Dogs are friendly: one that notices the hero trots over, stops a few steps
##   away with a wagging tail, and goes back to its patch when the hero leaves.
##
## - The red-horned goat (kind "billy") is the village's bully. From time to time
##   it paws the ground, shouts its war cry and charges at the hero in a straight
##   line (it locks on when the wind-up ends, so a sidestep makes it miss). A bump
##   shoves the hero but does no harm. After BUMPS bumps it trots off and sulks for
##   COOLDOWN seconds of game time (the timer runs on physics ticks, like the
##   hero's spell and fight cooldowns, so a paused game does not count). It has no
##   life points, so it cannot be hurt or killed.
##
## At night they settle down: legs tucked, head folded away.
##
## The geese are built from a few primitive shapes, which share their meshes and materials;
## the goats are the sheep model dressed as goats (GoatModel). Both cost little. Only bodies near the hero move
## and animate, and the ones far from the camera are hidden.

## shy: how close the hero may come before it bolts (metres, 0: never);
## walk and run: speeds (m/s); roam: how far from home it strolls (tiles);
## stride: metres of ground per leg swing, so the legs keep pace with the body;
## notice: from how far a dog comes over to the hero (metres).
const KINDS := {
	"goose": {"name": "goose", "shy": 4.5, "walk": 0.9, "run": 4.2, "roam": 3, "stride": 0.55, "scale": 1.15},
	"goat": {"name": "goat", "shy": 4.0, "walk": 1.1, "run": 5.0, "roam": 4, "stride": 0.8, "scale": 1.0},
	"sheep": {"name": "sheep", "shy": 4.0, "walk": 0.75, "run": 4.0, "roam": 3, "stride": 0.7, "scale": 1.0},
	# Never shy: it picks fights instead (see the BILLY constants).
	"billy": {"name": "red-horned goat", "shy": 0.0, "walk": 1.2, "run": 5.0, "roam": 4, "stride": 0.8, "scale": 1.12},
	# The ones with a model of their own (see MODELS): the legs keep pace through Stride.
	"dog": {"name": "dog", "shy": 0.0, "walk": 1.6, "run": 5.5, "roam": 7, "stride": 0.8, "scale": 1.0, "notice": 11.0},
	"cow": {"name": "cow", "shy": 5.0, "walk": 1.0, "run": 4.5, "roam": 3, "stride": 1.0, "scale": 1.0},
	"bull": {"name": "bull", "shy": 6.5, "walk": 1.0, "run": 4.5, "roam": 2, "stride": 1.0, "scale": 1.0},
}
## The models of "Ultimate Animated Animals" by Quaternius (CC0, see
## assets/animals/LICENSE.txt), by kind and coat: file and scale. The model's own
## colours are kept.
const MODELS := {
	"dog": {"": ["ShibaInu", 0.26], "black": ["Husky", 0.3]},
	"cow": {"": ["Cow", 0.3]},
	"bull": {"": ["Bull", 0.32]},
	# The sheep of the Farm Animals pack, with a Walk, Gallop and Eating made for it (tools/build_sheep.gd).
	"sheep": {"": ["Sheep", 0.25]},
	# The goats are that sheep turned into goats (see GoatModel); the red-horned one is a little bigger.
	"goat": {"": ["Sheep", 0.22]},
	"billy": {"": ["Sheep", 0.26]},
}
## A sneaking hero is noticed only this much closer.
const SNEAK_FACTOR := 0.5
## How far a frightened animal runs from home at most (tiles), and how far
## the hero must be before it settles down again (times its shy distance).
const FLEE_ROAM := 6
const CALM_FACTOR := 1.6
## A startled goose scares the flock mates within this many metres.
const ALARM_RANGE := 14.0
## A dog stops this far from the hero, and loses interest this far away.
const GREET_GAP := 2.4
const GREET_LOSE := 15.0
## The red-horned goat: it picks a fight with a hero within BILLY_RANGE metres,
## waits BILLY_WAIT seconds (random) before the first wind-up, shows its wind-up
## for WINDUP seconds, then charges at CHARGE_SPEED for at most CHARGE_TIME
## seconds, bumping the hero within BUMP_RANGE metres. After BUMPS bumps it
## retreats and rests COOLDOWN seconds (10 minutes); between two bumps it
## catches its breath for RECOVER seconds. The war cry is its speech line.
const BILLY_RANGE := 14.0
const BILLY_WAIT := Vector2(4.0, 9.0)
const WINDUP := 1.4
const CHARGE_SPEED := 7.5
const CHARGE_TIME := 1.6
const BUMP_RANGE := 1.3
const BUMPS := 3
const RECOVER := 2.5
const COOLDOWN := 600.0
const CRY := "mähhhhh, feeeeellll maaaiiiii  hoooooorrrrnsss!!!"
## Farther from the hero than this the animal does not move, farther than
## HIDE_RANGE it is not drawn.
const ACTIVE_RANGE := 100.0
const HIDE_RANGE := 80.0
## How far a body drops when it lies down (its legs' length), per kind.
const LEG := {"goose": 0.22}
## Where a goose's wing joins its body (right side; the left mirrors x). The body is an
## ellipsoid of radii (0.18, 0.17, 0.31) around (0, 0.36, 0); this point lies inside it.
const WING_SHOULDER := Vector3(0.13, 0.46, 0.0)

static var _meshes := {}
static var _mats := {}
static var _sheep_mats := {}

var level: Outdoor
var kind := "goose"
var home := Vector2i.ZERO
## The tiles the animal may never leave (a Rect2i with an area), or an empty
## Rect2i for one that roams free. The cattle live in the pen (see Corral).
var pen := Rect2i()
## "graze", "idle", "stroll", "flee", "greet" or "rest" (asleep at night).
var state := "idle"
## The others of its flock: geese keep near them.
var mates: Array[FarmAnimal] = []
## What it looks like: a colour name (see _coat), "" for the kind's usual one.
var coat := ""
## The red-horned goat: bumps so far in this round, seconds of cooldown left,
## seconds until the next wind-up, the line of the charge and its speech bubble.
var bumps := 0
var cooldown := 0.0
var _charge_wait := -1.0
var _dir := Vector3.ZERO
var _bubble: SpeechBubble
var _bubble_time := 0.0
var _stats: Dictionary
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector3] = []
var _speed := 0.0
var _timer := 0.0
var _check := 0.0
var _phase := 0.0
var _clock := 0.0
var _swing := 0.0
var _resting := false
var _waiting := 0.0
var _rig: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _wings: Array[Node3D] = []
var _model_name := ""
var _anim: AnimationPlayer
var _playing := ""


func setup(owner_level: Outdoor, animal_kind: String, cell: Vector2i, look := "", fenced_in := Rect2i()) -> void:
	level = owner_level
	pen = fenced_in
	kind = animal_kind
	home = cell
	coat = look
	_stats = KINDS[kind]
	_rng.seed = hash(kind) + cell.x * 131 + cell.y * 7 + hash(look)


## Called after the footprint pass moved this animal to a free spot: the way on from there is found again.
func footprint_moved() -> void:
	_path.clear()


func _ready() -> void:
	add_to_group(Footprint.GROUP)
	SmoothMotion.follow_ticks(self)
	_rig = Node3D.new()
	add_child(_rig)
	_rig.scale = Vector3.ONE * float(_stats.scale)
	if MODELS.has(kind):
		_build_model()
	else:
		_build_goose()
	if kind == "billy":
		_bubble = SpeechBubble.new()
		_bubble.position.y = 2.3
		add_child(_bubble)
	rotation.y = _rng.randf() * TAU
	_phase = _rng.randf() * TAU
	_begin("graze" if _rng.randf() < 0.5 else "idle", _rng.randf_range(0.5, 5.0))


func is_fleeing() -> bool:
	return state == "flee"


## How close the hero may come right now before this animal bolts.
func shy_distance() -> float:
	var d: float = _stats.shy
	if level and level.player and level.player.get("sneaking"):
		d *= SNEAK_FACTOR
	return d


## Bolts from `danger` (a startled flock mate, a slime).
func bolt_from(danger: Vector3) -> void:
	if state != "flee":
		_flee_from(danger)


## Whether this animal may stop on a tile: open ground that is no front
## step of a building and no gate, so a door or a way is never blocked.
## Public so the village (see VillageFarm) and the test can use the same rule.
static func may_stand(lvl: Outdoor, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= lvl.width or c.y >= lvl.height or not lvl.is_open(c):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var ch := lvl.cell_char(c + Vector2i(dx, dy))
			if Outdoor.BLOCK_CHARS.contains(ch) or ch == "\\" or ch == "a" or ch == "q" or ch == "F" or ch == "v":
				return false
	return true


# --- Behaviour ---------------------------------------------------------------

func _begin(new_state: String, time: float) -> void:
	state = new_state
	_timer = time


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var hero: Node3D = level.player
	if kind == "billy":
		_tick_billy(delta)
	_check -= delta
	var away := global_position - hero.global_position
	away.y = 0.0
	if _check <= 0.0:
		_check = 0.5
		visible = away.length() < HIDE_RANGE
	if away.length() > ACTIVE_RANGE:
		return
	# A walk or a trot sets the swing to 1 again every tick. A model's legs stop at once
	# (no gliding on a walk cycle); the primitive bodies let theirs settle.
	_swing = 0.0 if _anim != null else move_toward(_swing, 0.0, delta * 6.0)
	var alive: bool = not hero.get("dead")
	var shy := shy_distance()
	var near: bool = alive and shy > 0.0 and away.length() < shy
	if near and state != "flee":
		_wake()
		_flee_from(hero.global_position)
		_alarm_flock(hero.global_position)
	if kind == "dog" and alive and state != "flee":
		_mind_hero(away.length())
	if _resting:
		return
	if kind == "billy" and alive and state in ["graze", "idle", "stroll"]:
		_pick_fight(delta, away.length(), hero)
	match state:
		"graze", "idle":
			if shy > 0.0 and away.length() < shy * CALM_FACTOR:
				# Wary: stops grazing and keeps an eye on the hero.
				_turn_to(-away, delta)
			_timer -= delta
			if _timer <= 0.0:
				_next()
		"stroll", "flee":
			_walk(delta)
			if _path.is_empty():
				if state == "flee" and shy > 0.0 and away.length() < shy * CALM_FACTOR:
					_flee_from(hero.global_position)
				else:
					_begin("idle", _rng.randf_range(1.0, 3.0))
		"greet":
			_greet(away, delta)
		"windup":
			_windup(delta, hero)
		"charge":
			_charge(delta, hero)
		"recover":
			_turn_to(-away, delta)
			_timer -= delta
			if _timer <= 0.0:
				_begin("idle", 0.5)


## The cooldown and the speech bubble run all the time, even far from the hero.
func _tick_billy(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	_bubble_time = maxf(0.0, _bubble_time - delta)
	if _bubble_time <= 0.0 and _bubble.is_shown():
		_bubble.hide_line()


## True while the red-horned goat may start a fight.
func can_fight() -> bool:
	return kind == "billy" and cooldown <= 0.0 and not level.night and not _resting


## Near a hero and not on cooldown, it waits a few seconds and then winds up.
func _pick_fight(delta: float, gap: float, hero: Node3D) -> void:
	var busy: bool = hero.has_method("protected") and hero.protected()
	if not can_fight() or gap > BILLY_RANGE or busy:
		_charge_wait = -1.0
		return
	if _charge_wait < 0.0:
		_charge_wait = _rng.randf_range(BILLY_WAIT.x, BILLY_WAIT.y)
	_charge_wait -= delta
	if _charge_wait <= 0.0:
		_start_windup()


## It stops, lowers its head, paws the ground and shouts: a clear sign to step aside.
func _start_windup() -> void:
	_charge_wait = -1.0
	_path.clear()
	_begin("windup", WINDUP)
	_bubble.show_line(Lang.t("Rothorn-Ziege"), Lang.t(CRY), true)
	_bubble_time = WINDUP + 2.0
	Effects.head_text(level, self, 2.0, "!", Color(1.0, 0.25, 0.2))


func _windup(delta: float, hero: Node3D) -> void:
	_turn_to(hero.global_position - global_position, delta * 1.5)
	_timer -= delta
	if _timer <= 0.0:
		# It locks on now: a sidestep makes it miss.
		_dir = _flat(hero.global_position - global_position).normalized()
		_begin("charge", CHARGE_TIME)


func _charge(delta: float, hero: Node3D) -> void:
	var step := CHARGE_SPEED * delta
	var next := global_position + _dir * step
	if not WalkRules.can_step(level, global_position, next, true):
		_begin("recover", RECOVER)
		return
	global_position = next
	_turn_to(_dir, delta)
	_swing = 1.0
	_phase += step / float(_stats.stride) * TAU * 0.5
	if not hero.get("dead") and _flat(hero.global_position - global_position).length() < BUMP_RANGE:
		_bump(hero)
		return
	_timer -= delta
	if _timer <= 0.0:
		_begin("recover", RECOVER)


## A bump shoves the hero and does no harm. The third one sends the goat off to sulk.
func _bump(hero: Node3D) -> void:
	bumps += 1
	if hero.has_method("shove"):
		hero.shove(global_position)
	Comic.pop(hero.global_position, "hit")
	if bumps >= BUMPS:
		bumps = 0
		cooldown = COOLDOWN
		_flee_from(hero.global_position)
	else:
		_begin("recover", RECOVER)


## A dog that notices the hero trots over, and goes home when the hero leaves.
func _mind_hero(gap: float) -> void:
	if state == "greet":
		if gap > GREET_LOSE:
			_path.clear()
			_begin("idle", 1.0)
		return
	if gap < float(_stats.notice):
		_wake()
		_begin("greet", 1.0)
		_path.clear()


func _greet(away: Vector3, delta: float) -> void:
	var to := -away
	if to.length() > GREET_GAP + 0.6:
		_speed = 2.2 if to.length() > 7.0 else 1.0
		_path.clear()
		var step := _pace("Gallop" if _speed > 1.5 else "Walk", _speed) * delta
		_swing = 1.0
		var next := global_position + to.normalized() * minf(step, to.length() - GREET_GAP)
		if WalkRules.can_step(level, global_position, next, true):
			global_position = next
			_phase += step / float(_stats.stride) * TAU * 0.5
		else:
			# A wall or a shut gate between them: it stands and looks.
			_swing = 0.0
		_turn_to(to, delta)
	else:
		_turn_to(to, delta)


## Calm again: graze a while, look around, or stroll to another spot.
func _next() -> void:
	if level.night:
		_rest()
		return
	var roll := _rng.randf()
	if roll < 0.4:
		_begin("graze", _rng.randf_range(3.0, 8.0))
	elif roll < 0.55:
		_begin("idle", _rng.randf_range(2.0, 4.0))
	else:
		if not _set_path(_pick_spot()):
			_begin("idle", 2.0)
			return
		state = "stroll"
		_speed = _stats.walk


## Lies down for the night, on the spot.
func _rest() -> void:
	_resting = true
	state = "rest"
	_timer = _rng.randf_range(8.0, 16.0)
	_set_lying(true)


func _wake() -> void:
	if _resting:
		_resting = false
		_set_lying(false)
		_begin("idle", 1.0)


func _alarm_flock(danger: Vector3) -> void:
	if kind != "goose":
		return
	for m in mates:
		if is_instance_valid(m) and m != self and m.state != "flee" and m.global_position.distance_to(global_position) < ALARM_RANGE:
			m._wake()
			m.bolt_from(danger)


func _flee_from(danger: Vector3) -> void:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var here := level.world_to_cell(global_position)
	for i in 24:
		var c := home + Vector2i(_rng.randi_range(-FLEE_ROAM, FLEE_ROAM), _rng.randi_range(-FLEE_ROAM, FLEE_ROAM))
		if c == here or not _ok(c):
			continue
		var p := level.cell_to_world(c)
		# Away from the danger, and not past it on the way.
		var score := _flat(p - danger).length() - 0.5 * _flat(p - global_position).length()
		if _flat(p - danger).dot(_flat(global_position - danger)) < 0.0:
			score -= 100.0
		if score > best_score:
			best_score = score
			best = c
	if best == Vector2i(-1, -1) or not _set_path(level.cell_to_world(best)):
		_begin("idle", 1.0)
		return
	state = "flee"
	_speed = _stats.run


## A spot to stroll to: near a flock mate (geese keep together) or near home.
func _pick_spot() -> Vector3:
	var centre := home
	if kind == "goose" and not mates.is_empty() and _rng.randf() < 0.7:
		var m: FarmAnimal = mates[_rng.randi() % mates.size()]
		if is_instance_valid(m):
			centre = level.world_to_cell(m.global_position)
	var radius: int = _stats.roam
	for i in 20:
		var c := centre + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if _ok(c) and maxi(absi(c.x - home.x), absi(c.y - home.y)) <= int(_stats.roam) + 3:
			return level.cell_to_world(c)
	return level.cell_to_world(home)


## A tile it may stop on: standable ground of its own kind (geese and goats
## keep to the grass, dogs also use the paths and the square).
func _ok(c: Vector2i) -> bool:
	if pen.has_area() and not pen.has_point(c):
		return false
	if not may_stand(level, c):
		return false
	var ch := level.cell_char(c)
	return ch == "." or (kind == "dog" and (ch == "," or ch == ":"))


func _set_path(target: Vector3) -> bool:
	_path.assign(WalkRules.path(level, global_position, target, _rng))
	return not _path.is_empty()


func _walk(delta: float) -> void:
	if _path.is_empty():
		return
	var to := _flat(_path[0] - global_position)
	var step := _pace("Gallop" if (state == "flee" or _speed > 3.0) else "Walk", _speed) * delta
	var target := Vector3(_path[0].x, global_position.y, _path[0].z) if to.length() <= step else global_position + to.normalized() * step
	if not WalkRules.can_step(level, global_position, target):
		# A gate was shut (or a wall stands) ahead: stand, then find the way again.
		_swing = 0.0
		_waiting += delta
		if _waiting >= WalkRules.MAKE_WAY:
			_waiting = 0.0
			var goal: Vector3 = _path[_path.size() - 1]
			if not _set_path(goal):
				_begin("idle", 1.0)
		return
	_waiting = 0.0
	_swing = 1.0
	_phase += step / float(_stats.stride) * TAU * 0.5
	global_position = target
	if to.length() <= step:
		_path.pop_front()
	_turn_to(to, delta)


func _turn_to(direction: Vector3, delta: float) -> void:
	WalkRules.turn(self, direction, delta, WalkRules.TURN_RATE * (1.25 if state in ["flee", "charge"] else 1.0))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Pose (every frame, only while drawn) -----------------------------------------

func _process(delta: float) -> void:
	if not visible or _rig == null:
		return
	_clock += delta
	var moving := _swing > 0.05
	var fleeing := state == "flee"
	var greeting := state == "greet" and _swing > 0.05
	if _anim != null:
		_pose_model(moving)
		return
	# Legs swing with the stride.
	var amp := 0.7 if (fleeing or greeting) else 0.5
	for i in _legs.size():
		# Diagonal pairs of a four-legged animal (and the two goose legs) swing in step.
		var opposite := (i == 1 or i == 2) if _legs.size() == 4 else i == 1
		_legs[i].rotation.x = sin(_phase + (PI if opposite else 0.0)) * amp * _swing
	# The body bobs a little as it goes.
	var bob := absf(sin(_phase)) * 0.03 * _swing
	var drop: float = float(LEG[kind]) if _resting else 0.0
	_rig.position.y = lerpf(_rig.position.y, bob - drop, minf(1.0, delta * 8.0))
	_pose_goose(moving, fleeing)


func _pose_goose(moving: bool, fleeing: bool) -> void:
	var peck := state == "graze" and not _resting
	var want := 0.0
	if _resting:
		want = -1.9
	elif peck:
		# Short, quick pecks at the ground.
		want = 0.9 + 0.5 * maxf(0.0, sin(_clock * 5.0 + _phase)) if sin(_clock * 0.9 + _phase) > -0.4 else 0.2
	elif moving:
		# The head nods with each step.
		want = 0.1 + sin(_phase * 2.0) * 0.12
	_head.rotation.x = lerpf(_head.rotation.x, want, 0.25)
	for i in _wings.size():
		var flap := (0.9 + sin(_clock * 28.0) * 0.5) if fleeing else (0.0 if not _resting else -0.1)
		_wings[i].rotation.z = lerpf(_wings[i].rotation.z, (1.0 if i == 0 else -1.0) * flap, 0.4)


## A model animal plays its walk, gallop, grazing or idle animation.
func _pose_model(moving: bool) -> void:
	if state == "windup":
		# The red-horned goat's wind-up: head down, shaking, the whole body rocks as it paws.
		_play("Eating", 2.5)
		_rig.rotation.z = sin(_clock * 22.0) * 0.04
		return
	elif _rig.rotation.z != 0.0:
		_rig.rotation.z = 0.0
	if moving:
		return
	_play("Eating" if state == "graze" else "Idle", 1.0)


func _play(anim: String, rate: float) -> void:
	if _playing != anim:
		_playing = anim
		_anim.play(anim, 0.25)
	_anim.speed_scale = rate


## The ground speed a model animal really moves in `anim` when it means to go at
## `speed`: a walk no faster than its legs step, every gait played just fast
## enough that its planted feet stay put (see Stride).
func _pace(anim: String, speed: float) -> float:
	if _anim == null:
		return speed
	var rig := Stride.rig_of(_model_name)
	var size := _rig.scale.z
	var moved := minf(speed, Stride.top_speed(rig, anim, size)) if anim == "Walk" else speed
	_play(anim, Stride.playback(rig, anim, size, moved))
	return moved


func _set_lying(on: bool) -> void:
	for leg in _legs:
		leg.visible = not on


# --- Models -------------------------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _mesh(shape: String) -> Mesh:
	if not _meshes.has(shape):
		match shape:
			"ball":
				var s := SphereMesh.new()
				s.radius = 0.5
				s.height = 1.0
				s.radial_segments = 12
				s.rings = 6
				_meshes[shape] = s
			"stick":
				var c := CylinderMesh.new()
				c.top_radius = 0.5
				c.bottom_radius = 0.5
				c.height = 1.0
				c.radial_segments = 6
				c.rings = 1
				_meshes[shape] = c
			"cone":
				var k := CylinderMesh.new()
				k.top_radius = 0.0
				k.bottom_radius = 0.5
				k.height = 1.0
				k.radial_segments = 6
				k.rings = 1
				_meshes[shape] = k
			_:
				var b := BoxMesh.new()
				_meshes[shape] = b
	return _meshes[shape]


## One part: a shape of the given size at `pos`, in `color`.
func _part(parent: Node3D, shape: String, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _mesh(shape)
	m.material_override = _mat(color)
	m.position = pos
	m.scale = size
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## A leg that swings from its top: a pivot with a stick hanging down.
func _leg(top: Vector3, length: float, thick: float, color: Color, foot: Color) -> void:
	var p := _pivot(_rig, top)
	_part(p, "stick", color, Vector3(0, -length * 0.5, 0), Vector3(thick, length, thick))
	_part(p, "box", foot, Vector3(0, -length + thick * 0.2, thick * 0.9), Vector3(thick * 1.5, thick * 0.5, thick * 2.4))
	_legs.append(p)


func _build_goose() -> void:
	var white := Color(0.95, 0.94, 0.9)
	var grey := Color(0.82, 0.8, 0.76)
	var orange := Color(0.95, 0.55, 0.12)
	var eye := Color(0.08, 0.06, 0.05)
	if coat == "grey":
		white = Color(0.62, 0.58, 0.52)
		grey = Color(0.5, 0.46, 0.42)
	_part(_rig, "ball", white, Vector3(0, 0.36, 0), Vector3(0.36, 0.34, 0.62))
	# Tail, lifted a little.
	_part(_rig, "cone", white, Vector3(0, 0.42, -0.34), Vector3(0.16, 0.22, 0.16), Vector3(-1.9, 0, 0))
	# The neck rises from the chest; the head hangs from the pivot.
	_head = _pivot(_rig, Vector3(0, 0.46, 0.22))
	_part(_head, "stick", white, Vector3(0, 0.17, 0.04), Vector3(0.09, 0.4, 0.09), Vector3(0.2, 0, 0))
	var top := _pivot(_head, Vector3(0, 0.37, 0.09))
	_part(top, "ball", white, Vector3.ZERO, Vector3(0.13, 0.12, 0.17))
	_part(top, "box", orange, Vector3(0, -0.01, 0.12), Vector3(0.06, 0.035, 0.12))
	_part(top, "ball", eye, Vector3(0.05, 0.02, 0.04), Vector3(0.03, 0.03, 0.03))
	_part(top, "ball", eye, Vector3(-0.05, 0.02, 0.04), Vector3(0.03, 0.03, 0.03))
	# Wings folded along the sides; they open when the goose bolts.
	# The shoulder sits just inside the body's surface, so the wing stays joined when it flaps.
	for side in [1.0, -1.0]:
		var w := _pivot(_rig, Vector3(side * WING_SHOULDER.x, WING_SHOULDER.y, WING_SHOULDER.z))
		_part(w, "ball", grey, Vector3(side * 0.04, -0.06, -0.04), Vector3(0.1, 0.24, 0.46))
		_wings.append(w)
	for side in [1.0, -1.0]:
		_leg(Vector3(side * 0.08, 0.26, 0.02), 0.24, 0.035, orange, orange)


func _build_model() -> void:
	var pick: Array = MODELS[kind].get(coat, MODELS[kind][""])
	_model_name = pick[0]
	var model: Node3D = load("res://assets/animals/%s.glb" % _model_name).instantiate()
	_rig.add_child(model)
	var model_scale: Variant = pick[1]
	_rig.scale = model_scale if model_scale is Vector3 else Vector3.ONE * float(model_scale)
	if kind == "sheep":
		_fleece(model)
	elif kind in ["goat", "billy"]:
		GoatModel.dress(model, coat, kind == "billy")
	_anim = model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walk", "Gallop", "Eating"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle", 1.0)


## A sheep is woolly: the model's white body gets the fleece material (soft clumps, lit by a
## bump map so the wool looks curly), its black head and legs a dark one. The materials
## are built once and shared by the whole flock.
func _fleece(model: Node3D) -> void:
	if _sheep_mats.is_empty():
		var noise := _fleece_noise()
		var wool := StandardMaterial3D.new()
		wool.albedo_color = Color(0.97, 0.93, 0.84)
		wool.albedo_texture = _fleece_texture(noise)
		wool.normal_enabled = true
		wool.normal_texture = _fleece_normals(noise)
		wool.normal_scale = 2.2
		wool.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		wool.uv1_triplanar = true
		wool.uv1_scale = Vector3.ONE * 18.0
		wool.roughness = 1.0
		_sheep_mats["White"] = wool
		_sheep_mats["Black"] = _mat(Color(0.14, 0.11, 0.1))
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and _sheep_mats.has(m.resource_name):
				mi.set_surface_override_material(s, _sheep_mats[m.resource_name])


## Soft curly clumps (a seamless height map, 128 px) for the fleece.
static func _fleece_noise() -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.frequency = 0.07
	noise.seed = 11
	return noise.get_seamless_image(128, 128)


## The clumps' colour, light on top and dark in the cracks between them.
static func _fleece_texture(noise: Image) -> ImageTexture:
	var size := noise.get_width()
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.86 + 0.14 * (1.0 - noise.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(v, v, v * 0.97))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The same clumps as a normal map, so the light catches each curl.
static func _fleece_normals(noise: Image) -> ImageTexture:
	var img := noise.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	img.bump_map_to_normal_map(10.0)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
